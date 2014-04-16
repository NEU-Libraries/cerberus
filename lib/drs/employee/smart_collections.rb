module Drs::Employee::SmartCollections
  extend ActiveSupport::Concern

  included do
    after_destroy :purge_personal_graph
  end

  def user_root_collection
    return self.smart_collections.find{ |f| f.smart_collection_type == 'User Root' }
  end

  def research_publications_collection
    find_by_smart_collection_type('Research Publications')
  end

  def other_publications_collection
    find_by_smart_collection_type('Other Publications')
  end

  def data_sets_collection
    find_by_smart_collection_type('Datasets')
  end

  def presentations_collection
    find_by_smart_collection_type('Presentations')
  end

  def learning_objects_collection
    find_by_smart_collection_type('Learning Objects')
  end

  def sorted_smart_collections
    [research_publications_collection, other_publications_collection, data_sets_collection, presentations_collection, learning_objects_collection]
  end

  def personal_collections
    c_array = self.smart_collections.select { |f| (f.smart_collection_type == 'miscellany') && (f.parent.pid == self.user_root_collection.pid) }
    return c_array.map{ |x| SolrDocument.new(ActiveFedora::SolrService.query("id:\"#{x.pid}\"").first) }
  end

  private

    def find_by_smart_collection_type(string, root = false)
      collection = self.smart_collections.find{ |f|
        (f.smart_collection_type == string) &&
        (!f.parent.nil?) &&
        (f.parent.pid == self.user_root_collection.pid)
      }
      solrCollection = SolrDocument.new(ActiveFedora::SolrService.query("id:\"#{collection.pid}\"").first)
    end

    def purge_personal_graph
      self.user_root_collection.recursive_delete if !self.smart_collections.empty?
    end
end
