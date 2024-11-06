# frozen_string_literal: true

require 'rails_helper'

describe ProcessIptcJob do
  describe 'error handling' do
    let(:load_report) { LoadReport.create!(status: :in_progress) }
    let(:ingest) {
      IptcIngest.create_from_image_binary(
        "test.jpg",
        "fake_binary_data",
        { "test" => "metadata" },
        load_report.id
      )
    }

    it 'updates ingest status to failed when an error occurs' do
      allow(AtlasRb::Work).to receive(:create).and_raise(StandardError.new("Test error"))

      expect(Rails.logger).to receive(:error).with("Processing failed for ingest #{ingest.id}: Test error")
      expect(Rails.logger).to receive(:error).with(anything)

      expect {
        ProcessIptcJob.perform_now(ingest.id)
      }.to raise_error(StandardError, "Test error")

      expect(ingest.reload.status).to eq('failed')
    end
  end
end
