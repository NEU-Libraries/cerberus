# frozen_string_literal: true

class XmlIngest < ApplicationRecord
  include Ingestible

  validates :xml_filename, presence: true

  def self.create_from_spreadsheet_row(pid, file_name, load_report_id)
    Ingest.create!(
      ingestible: XmlIngest.new(xml_filename: file_name),
      pid: pid,
      status: :pending,
      load_report: LoadReport.find(load_report_id)
    )
  end
end
