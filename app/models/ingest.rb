# frozen_string_literal: true

class Ingest < ApplicationRecord
  self.abstract_class = true

  belongs_to :load_report

  enum :status, { pending: 0, processing: 1, completed: 2, failed: 3 }
end
