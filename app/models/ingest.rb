# frozen_string_literal: true

class Ingest < ApplicationRecord
  belongs_to :load_report

  enum status: { pending: 0, completed: 1, failed: 2 }

  validates :pid, presence: true
  validates :xml_filename, presence: true
  validates :status, presence: true

  def self.create_from_spreadsheet_row(row, load_report_id)
    create!(
      pid: row[0],
      xml_filename: row[1],
      status: :pending,
      load_report: LoadReport.find(load_report_id),
    )
  end
end
