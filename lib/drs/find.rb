module Drs
  module Find
    extend ActiveSupport::Concern

    included do
      def self.find(neu_id)
        return self.all if neu_id == :all

        obj = ActiveFedora::Base.find(neu_id, :cast => true)

        if !obj.instance_of?(super.class)
          raise Exceptions::SearchResultTypeError.new(neu_id, obj.class, super.class)
        end

        return obj
      end

      def self.find_children(filter = "none")
        # Search SOLR for all objects that have this object set as its Parent in the
        # properties datastream.

        # query = "{!lucene q.op=AND df=#{category_field}}#{category}"
        query = "{!lucene q.op=AND df=parent_id_tesim}#{self.pid}"
        (response, document_list) = get_search_results(:q => query)
        docs = response.docs.map { |x| SolrDocument.new(x) }
        return docs

      end
    end

  end
end
