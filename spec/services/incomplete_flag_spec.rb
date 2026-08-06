# frozen_string_literal: true

require 'rails_helper'

# Every caller is either a job's give-up handler or the tail of a successful
# enrichment run, so this must never raise: an unreachable Atlas would otherwise
# turn a handled failure into an unhandled one.
RSpec.describe IncompleteFlag do
  let(:work_id) { 'w-1' }

  describe '.set' do
    it 'flags the work with the token it was given' do
      allow(AtlasRb::Work).to receive(:mark_incomplete)

      described_class.set(work_id, reason: IncompleteReasons::PDF_RENDITION, nuid: '000000002')

      expect(AtlasRb::Work).to have_received(:mark_incomplete)
        .with(work_id, reason: 'pdf_rendition_gave_up', nuid: '000000002')
    end

    it 'logs and swallows an Atlas failure rather than raising into its caller' do
      allow(AtlasRb::Work).to receive(:mark_incomplete).and_raise(Faraday::ConnectionFailed.new('down'))
      allow(Rails.logger).to receive(:error)

      expect { described_class.set(work_id, reason: IncompleteReasons::FULL_TEXT) }.not_to raise_error
      expect(Rails.logger).to have_received(:error).with(/could not flag work w-1 as full_text_gave_up/)
    end
  end

  describe '.clear' do
    it 'clears the flag' do
      allow(AtlasRb::Work).to receive(:clear_incomplete)

      described_class.clear(work_id)

      expect(AtlasRb::Work).to have_received(:clear_incomplete).with(work_id)
    end

    it 'logs and swallows an Atlas failure' do
      allow(AtlasRb::Work).to receive(:clear_incomplete).and_raise(AtlasRb::Error.new('boom'))
      allow(Rails.logger).to receive(:error)

      expect { described_class.clear(work_id) }.not_to raise_error
      expect(Rails.logger).to have_received(:error).with(/could not clear the flag on work w-1/)
    end
  end
end
