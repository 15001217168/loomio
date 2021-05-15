class TaskService
  def self.parse_and_update(model, rich_text)
    update_model(model, parse_tasks(rich_text))
  end

  def self.parse_tasks(rich_text)
    Nokogiri::HTML::fragment(rich_text).search('li[data-type="taskItem"]').map do |el|
      identifiers = Nokogiri::HTML::fragment(el).
                    search("span[data-mention-id]").map do |el|
                      el['data-mention-id']
                    end
      usernames = identifiers.filter { |id_or_username| id_or_username.to_i.to_s != id_or_username }
      user_ids =  identifiers.filter { |id_or_username| id_or_username.to_i.to_s == id_or_username }

      {
        uid: (el['data-uid'] || (rand() * 100000000)).to_i,
        name: el.text,
        user_ids: user_ids,
        usernames: usernames,
        due_on: parse_date(el.text),
        done: el['data-checked'] == 'true',
        author_id: (el['data-author-id'] && el['data-author-id'].to_i) || nil
      }
    end
  end

  def self.update_model(model, tasks_data)
    uids = tasks_data.map {|t| t[:uid] }
    existing_uids = model.tasks.pluck(:uid)
    new_uids = uids - existing_uids
    removed_uids = existing_uids - uids

    # delete tasks which are not mentioned by uid
    # TODO maybe notify people if a task is deleted. or mark it as discarded
    model.tasks.where(uid: removed_uids).destroy_all

    # update existing tasks
    model.tasks.where(uid: existing_uids).each do |task|
      data = tasks_data.find { |t| t[:uid] == task.uid }

      mentioned_users = model.members.where('users.id in (:ids) or users.username in (:names)',
                                            ids: data[:user_ids],
                                            names: data[:usernames])
      new_users = mentioned_users.where('users.id not in (?)',  task.users.pluck(:id))
      removed_users = task.users.where('users.id not in (?)', mentioned_users.pluck(:id))

      task.update!(name: data[:name],
                   due_on: data[:due_on],
                   users: mentioned_users,
                   done: data[:done],
                   done_at: (!task.done && data[:done]) ? Time.now : task.done_at,
                   author: model.members.find_by('users.id': data[:author_id]))
    end

    # create tasks which dont yet exist
    tasks_data.filter{|t| new_uids.include?(t[:uid]) }.each do |data|
      users = model.members.where('users.id in (:ids) or users.username in (:names)',
                                  ids: data[:user_ids],
                                  names: data[:usernames])
      model.tasks.create(
        uid: data[:uid],
        name: data[:name],
        due_on: data[:due_on],
        users: users,
        done: data[:done],
        done_at: (data[:done] ? Time.now : nil),
        author: model.members.find_by('users.id': data[:author_id])
      )
    end
  end

  def self.parse_date(s)
    Date.parse s.match(/(\d\d\d\d)-(\d\d?)-(\d\d?)/).to_s
  rescue Date::Error
    nil
  end
end