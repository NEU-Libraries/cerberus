# frozen_string_literal: true

module Ingestible
  extend ActiveSupport::Concern

  included do
    has_one :ingest, as: :ingestible, touch: true
  end
end
