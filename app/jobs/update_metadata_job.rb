# frozen_string_literal: true

class UpdateMetadataJob < ApplicationJob
  queue_as :default

  def perform(ingest_id)
    ingest = Ingest.find(ingest_id)

    begin
      Tempfile.create(['update', '.xml'], binmode: true) do |temp_file|
        temp_file.write(ingest.ingestible.xml_content)
        temp_file.flush
        AtlasRb::Work.update(ingest.pid, temp_file.path)
      end

      ingest.update!(status: :completed)
    rescue StandardError => e
      Rails.logger.error("Update metadata failed for ingest #{ingest_id}: #{e.message}")
      ingest.update!(status: :failed)
      raise e
    end
  end
end
