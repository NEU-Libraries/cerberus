module Drs::Relationships 

  def single_lookup(relation, classes) 
   a = self.relationships(relation)
   result = a.map { |x| ActiveFedora::Base.find(x[12..-1], cast: true) }

   result.find { |x| classes.include? x.class } 
  end 

  def unique_assign_by_string(val, relation, valid_types, options = {}) 
    val.instance_of?(String) ? obj = ActiveFedora::Base.find(val, cast: true) : obj = val 

    if options[:allow_nil] && val.nil?
      purge_other_relationships(relation, valid_types) 
      false 
    elsif valid_types.include? obj.class
      purge_other_relationships(relation, valid_types)  
      self.add_relationship(relation, obj)
    else
      raise "Attempted to set #{relation.to_s} using a #{val.class}.  Valid choices are String or #{valid_types.to_s}" 
    end
  end

  # Return every descendent collection of this object
  def all_descendent_collections
    result = [] 
    self.each_depth_first do |child|
      if child.instance_of?(NuCollection) && !(child.eql?(self))
        result << child 
      end
    end
    return result 
  end

  # Return every descendent community of this object
  def all_descendent_communities
    result = [] 
    each_depth_first do |child|
      if child.instance_of?(Community) && !(child.eql?(self))
        result << child 
      end
    end
    return result 
  end

  def all_descendent_files 
    result = [] 
    each_depth_first do |child|
      if(child.instance_of?(NuCollection))
        result += child.child_files
      end
    end
    return result
  end

  # Delete all files/collections for which this item is root 
  def recursive_delete
    files = all_descendent_files 
    collections = all_descendent_collections
    communities = all_descendent_communities

    # Need to look it up again before you try to destroy it.
    # Is mystery. 
    files.each do |f|
      x = NuCoreFile.find(f.pid) if NuCoreFile.exists?(f.pid) 
      x.destroy
    end

    collections.each do |c| 
      x = NuCollection.find(c.pid) if NuCollection.exists?(c.pid) 
      x.destroy 
    end

    communities.each do |c| 
      x = Community.find(c.pid) if Community.exists?(c.pid) 
      x.destroy 
    end

    x = ActiveFedora::Base.find(self.pid, :cast => true)
    x.destroy
  end    

  private 

    # Remove relationships that would confuse the 'unique' component of 
    # of unique_assign_by_string
    def purge_other_relationships(relation, valid_types) 
      all = self.relationships(relation) 

      all.each do |rel|
        rel_obj = ActiveFedora::Base.find(rel[12..-1], cast: true)  
        if valid_types.include? rel_obj.class
          self.remove_relationship(relation, rel_obj) 
        end
      end
    end
end