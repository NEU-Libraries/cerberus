# frozen_string_literal: true

class BlobCreator < ApplicationService

  def initialize(work_id:, path:)
    @work_id = work_id
    @path = path
  end

  def call
    create_blob
  end

  private

    def create_blob
      # TODO: Atlas create
    end
end
