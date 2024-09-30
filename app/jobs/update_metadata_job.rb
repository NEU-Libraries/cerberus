# frozen_string_literal: true

class UpdateMetadataJob < ApplicationJob
  queue_as :default

  def perform(pid, xml_content, ingest_id)
    ingest = Ingest.find(ingest_id)
    begin
      Tempfile.create(['update', '.xml'], binmode: true) do |temp_file|
        temp_file.write(xml_content)
        temp_file.flush
        AtlasRb::Work.update(pid, temp_file.path)
      end
      ingest.update(status: :completed)
    rescue StandardError => e
      ingest.update(status: :failed)
    end
  end
end
