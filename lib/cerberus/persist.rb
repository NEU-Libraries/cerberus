module Cerberus
  module Persist
    extend ActiveSupport::Concern

    included do
      def self.save(*)

        retries = 0
        max_retries = 3

        begin
          super
        rescue RestClient::Conflict => e
          if retries <= max_retries
            retries += 1
            max_sleep_seconds = Float(2 ** retries) / 5
            sleep rand(0..max_sleep_seconds)
            retry
          else
            raise "Giving up on the server after #{retries} retries. Got error: #{e.message}"
          end
        end
      end
    end

  end
end
