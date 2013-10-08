module Drs
  module Find
    extend ActiveSupport::Concern

    included do
      def self.find(neu_id)
        obj = ActiveFedora::Base.find(neu_id, :cast => true)
      end
    end

  end
end