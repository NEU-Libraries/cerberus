# frozen_string_literal: true

class FileSetCreator < ApplicationService
  def initialize(work_id:, classification:)
    @work_id = work_id
    @classification = classification
  end

  def call
    create_file_set
  end

  private

    def create_file_set
      # TODO: Atlas create
    end
end
