# frozen_string_literal: true

class IptcIngest < ApplicationRecord
  include Ingestible

  validates :image_filename, presence: true
  validates :metadata, presence: true # Raw IPTC parsed metadata

  def self.create_from_image_binary(filename, image_file, metadata, load_report_id)
    # TODO Update To Actually Take in the PID?
    temp_pid = "work:#{SecureRandom.uuid}"

    Ingest.create!(
      ingestible: IptcIngest.new(
        image_filename: filename,
        image_file: image_file,
        metadata: metadata.to_json
      ),
      pid: temp_pid,
      status: :pending,
      load_report_id: load_report_id
    )
  end
end
