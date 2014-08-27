module Cerberus::Employee::SmartCollections
  extend ActiveSupport::Concern

  included do
    after_destroy :purge_personal_graph
  end

  def user_root_collection
    return self.smart_collections.find{ |f| f.smart_collection_type == 'User Root' }
  end

  private

    def purge_personal_graph
      if !self.user_root_collection.nil?
        self.user_root_collection.recursive_delete if !self.smart_collections.empty?
      end
    end
end
