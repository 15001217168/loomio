class Queries::ExploreGroups < Delegator
  def initialize
    @relation = Group.where(is_visible_to_public: true).
                            parents_only.
                            order('groups.memberships_count DESC')

  end

  def search_for(q)
    @relation = @relation.search_full_name(q) if q.present?
    self
  end

  def __getobj__
    @relation
  end
end
