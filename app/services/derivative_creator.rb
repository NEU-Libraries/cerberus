# frozen_string_literal: true

class DerivativeCreator < ApplicationService

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
      # TODO: Atlas
    end
end
