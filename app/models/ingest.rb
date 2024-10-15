# frozen_string_literal: true

class Ingest < ApplicationRecord
  belongs_to :load_report

  enum :status, { pending: 0, completed: 1, failed: 2 }

  delegated_type :ingestible, types: %w[ XmlIngest IptcIngest ]

  validates :pid, presence: true
  validates :status, presence: true
end
