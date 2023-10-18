# frozen_string_literal: true

module Derivatives
  class PdfJob
    include Sidekiq::Job
    include FileHelper

    def perform(file_id, work_id)
      # TODO: Atlas create
    end
  end
end
