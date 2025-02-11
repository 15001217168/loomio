class DemoService
	def self.refill_queue
		return unless ENV['FEATURES_DEMO_GROUPS']
		demo = Demo.where('demo_handle is not null').last
		return unless demo

		expected = 2
		remaining = Redis::List.new('demo_group_ids').value.size

		(expected - remaining).times do
			group = RecordCloner.new(recorded_at: demo.recorded_at).create_clone_group(demo.group)
			Redis::List.new('demo_group_ids').push(group.id)
		end
	end

	def self.take_demo(actor)
		group = Group.find(Redis::List.new('demo_group_ids').shift)
    group.creator = actor
    group.subscription = Subscription.new(plan: 'demo', owner: actor)
    group.add_member! actor
    group.save!
   	group
	end

	def self.ensure_queue
		return unless ENV['FEATURES_DEMO_GROUPS']
		existing_ids = Redis::List.new('demo_group_ids').value.select { |id| Group.where(id: id).exists? }
		Redis::List.new('demo_group_ids').clear
		Redis::List.new('demo_group_ids').unshift(*existing_ids) if existing_ids.any?
		refill_queue
	end

	def self.generate_demo_groups
		Demo.where("demo_handle IS NOT NULL").each do |template|
			Group.where(handle: template.demo_handle).update_all(handle: nil)
	    RecordCloner.new(recorded_at: template.recorded_at)
									.create_clone_group_for_public_demo(template.group, template.demo_handle)
		end
	end
end