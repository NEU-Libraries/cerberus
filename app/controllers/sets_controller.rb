class SetsController < ApplicationController 
  include Drs::ControllerHelpers::EditableObjects 

  helper_method :readable_child_files,
                :readable_child_collections,
                :readable_child_communities

  private 

    def readable_child_files(set) 
      return set.child_files.keep_if { |f| current_user_can_read? f } 
    end

    def readable_child_collections(set)
      return set.child_collections.keep_if { |c| current_user_can_read? c }
    end

    def readable_child_communities(set)
      return set.child_communities.keep_if { |c| current_user_can_read? c } 
    end
end