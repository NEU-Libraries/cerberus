# frozen_string_literal: true

class Ingest < ApplicationRecord
  belongs_to :load_report

  enum :status, { pending: 0, completed: 1, failed: 2 }

  validates :pid, presence: true
  validates :xml_filename, presence: true
  validates :status, presence: true

  def self.create_from_spreadsheet_row(pid, file_name, load_report_id)
    create!(
      pid: pid,
      xml_filename: file_name,
      status: :pending,
      load_report: LoadReport.find(load_report_id)
    )
  end
end
