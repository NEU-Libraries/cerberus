# frozen_string_literal: true

class DerivativeCreator < ApplicationService
  def initialize(file_id:, file_name:)
    @file_id = file_id
    @file_name = file_name
  end

  def call
    create_derivative
  end

  private

    def create_derivative
    end
end
