# frozen_string_literal: true

module Derivatives
  class PdfJob
    include Sidekiq::Job

    def perform(*args)
      # Make PDF from Word binary
    end
  end
end
