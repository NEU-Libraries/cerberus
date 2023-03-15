# frozen_string_literal: true

class DerivativeCreator < ApplicationService
  include MimeHelper

  def initialize(work_id:, file_id:, file_path:)
    @file_id = file_id
    @work_id = work_id
    @file_path = file_path
  end

  def call
    create_derivative
  end

  private

    def create_derivative
      classification = assign_classification(@file_path)
      # if FileSet is text && is a word document, kick off PDF derivative job
      if (classification == Classification.text) && (ext_check(@file_path) == Classification.text)
        # Run job
        Derivatives::PdfJob.perform_async(@file_id, @work_id)
      end
    end
end
