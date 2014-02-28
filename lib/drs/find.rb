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

      def self.find_children
        # Search SOLR for all objects that have this object set as its Parent in the
        # properties datastream.

        # TODO
      end
    end

  end
end
