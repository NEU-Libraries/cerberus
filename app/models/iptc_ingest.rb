# frozen_string_literal: true

class IptcIngest < ApplicationRecord
  include Ingestible

  validates :image_filename, presence: true
  validates :metadata, presence: true # Raw IPTC parsed metadata

  def self.create_from_image_binary(filename, metadata, load_report_id)
    # Generate a temporary PID/work ID
    temp_pid = "work:#{SecureRandom.uuid}"
    metadata_string = metadata.to_json

    Ingest.create!(
      ingestible: IptcIngest.new(
        image_filename: filename,
        metadata: metadata_string
      ),
      pid: temp_pid,
      status: :pending,
      load_report_id: load_report_id
    )
  end
end
