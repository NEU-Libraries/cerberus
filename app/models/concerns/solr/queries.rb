module Solr::Queries
  include ApplicationHelper

  def children
    solr_query("member_of_collection_ids_ssim:#{self.id} OR isPartOf_ssim:#{self.id}")
  end

  def sets
    solr_query("member_of_collection_ids_ssim:#{self.id} OR isPartOf_ssim:#{self.id} AND (generic_type_ssim:Set)")
  end

  def works
    solr_query("member_of_collection_ids_ssim:#{self.id} OR isPartOf_ssim:#{self.id} NOT (generic_type_ssim:Set)")
  end

  def each_depth_first
    self.set_children.each do |child|
      child.each_depth_first do |c|
        yield c
      end
    end

    yield self
  end

end
