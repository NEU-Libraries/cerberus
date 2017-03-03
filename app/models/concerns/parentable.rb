module Parentable

  def parent=(parent_obj)
    if self.class == Community || (self.class == Collection && parent_obj.class == Community)
      self.community = parent_obj
    else
      self.member_of_collections = [parent_obj]
    end
  end

  def parent
    if self.class == Collection
      !self.member_of_collection_ids.first.nil? ? Collection.find(self.member_of_collection_ids.first) : self.community
    elsif self.class == Community
      self.community
    else
      ActiveFedora::Base.find(self.member_of_collections.first.id)
    end
  end

end
