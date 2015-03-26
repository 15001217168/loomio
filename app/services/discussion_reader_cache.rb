class DiscussionReaderCache
  attr_accessor :user, :cache

  def initialize(user: nil, discussions: [])
    return unless user && discussions

    @user, @cache = user, {}
    DiscussionReader.includes(:discussion)
                    .where(user_id: user.id,
                           discussion_id: discussions.map(&:id))
                    .each do |reader|
      cache[reader.discussion_id] = reader
    end
  end

  def get_for(discussion)
    cache.fetch discussion.id, DiscussionReader.for(discussion: discussion, user: user)
  end

end
