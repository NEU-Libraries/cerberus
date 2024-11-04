# frozen_string_literal: true

class XmlIngest < ApplicationRecord
  include Ingestible

  validates :xml_filename, presence: true
  validates :xml_content, presence: true

  def self.create_from_spreadsheet_row(pid, filename, xml_content, load_report_id)
    Ingest.create!(
      ingestible: XmlIngest.new(
        xml_filename: filename,
        xml_content: xml_content
      ),
      pid: pid,
      status: :pending,
      load_report_id: load_report_id
    )
  end
end
