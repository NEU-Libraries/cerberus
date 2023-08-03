module Cerberus
  module Find
    extend ActiveSupport::Concern

    included do
      def self.find(neu_id)
        return self.all if neu_id == :all

        retries = 0
        max_retries = 3

        begin
          obj = ActiveFedora::Base.find(neu_id, :cast => true)
        rescue SystemCallError => e
          if retries <= max_retries
            retries += 1
            max_sleep_seconds = Float(2 ** retries) / 5
            sleep rand(0..max_sleep_seconds)
            retry
          else
            raise "Giving up on the server after #{retries} retries. Got error: #{e.message}"
          end
        end

        if !obj.instance_of?(super.class)
          raise Exceptions::SearchResultTypeError.new(neu_id, obj.class, super.class)
        end

        return obj
      end
    end

  end
end
