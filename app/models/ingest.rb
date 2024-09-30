# frozen_string_literal: true

class Ingest < ApplicationRecord
  enum status: { pending: 0, completed: 1, failed: 2 }

  validates :pid, presence: true
  validates :xml_filename, presence: true
  validates :status, presence: true

  def self.create_from_spreadsheet_row(row)
    create!(
      pid: row[0],
      xml_filename: row[1],
      status: :pending
    )
  end
end
