# frozen_string_literal: true
module Cerberus
  module Noid
    extend ActiveSupport::Concern

    def assign_id
      service.mint
    end

    private

    def service
      @service ||= ::Noid::Rails::Service.new
    end
  end
end
