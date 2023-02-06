# frozen_string_literal: true

module Derivatives
  class ExcelJob
    include Sidekiq::Job

    def perform(*args)
      # Do something
    end
  end
end
