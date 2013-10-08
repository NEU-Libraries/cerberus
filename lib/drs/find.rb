module Drs
  module Find
    extend ActiveSupport::Concern

    included do
      def self.find(neu_id)
        obj = ActiveFedora::Base.find(neu_id, :cast => true)
        
        if !obj.instance_of?(super.class)
          raise SearchResultTypeError.new(neu_id, obj.class, super.class)
        end

        return obj
      end
    end

    class SearchResultTypeError < StandardError 
      def initialize(pid, objClass, superClass)
        super "Expected pid of #{pid} to return type #{superClass} but got #{objClass}"
      end
    end

  end
end