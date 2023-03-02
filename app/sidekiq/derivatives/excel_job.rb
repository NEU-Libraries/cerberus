# frozen_string_literal: true

module Derivatives
  class ExcelJob
    include Sidekiq::Job

    def perform(*args)
      # Make CSV from Excel binary
    end
  end
end
