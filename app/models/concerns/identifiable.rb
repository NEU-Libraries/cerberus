# frozen_string_literal: true

module Identifiable
  extend ActiveSupport::Concern

  included do
    attr_json :valkyrie_id, :string
  end
end
