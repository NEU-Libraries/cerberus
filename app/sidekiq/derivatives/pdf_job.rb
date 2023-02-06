# frozen_string_literal: true

module Derivatives
  class PdfJob
    include Sidekiq::Job

    def perform(*args)
      # Do something
    end
  end
end
