# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DepositDerivativesJob, type: :job do
  include ActiveJob::TestHelper

  let(:work_id) { 'w-dep' }
  let(:base) { 'http://example.com/iiif/3/987654321.jp2' }
  let(:widths) { { small: 149, large: 503 } }

  before { allow(DerivativeCreationJob).to receive(:perform_now) }

  it 'recovers the JP2 base from the thumbnail Delegate URI and hands off the widths' do
    allow(AtlasRb::Work).to receive(:find).with(work_id)
                                          .and_return(AtlasRb::Mash.new(thumbnail: "#{base}/full/!85,85/0/default.jpg"))

    described_class.new.perform(work_id, widths)

    expect(DerivativeCreationJob).to have_received(:perform_now).with(work_id, base, widths: widths)
  end

  it 'raises ThumbnailNotReady while the thumbnail is still in flight (rides retry_on)' do
    allow(AtlasRb::Work).to receive(:find).with(work_id).and_return(AtlasRb::Mash.new(thumbnail: nil))

    expect { described_class.new.perform(work_id, widths) }
      .to raise_error(described_class::ThumbnailNotReady)
    expect(DerivativeCreationJob).not_to have_received(:perform_now)
  end

  it 'logs and swallows when retries exhaust without a thumbnail (deposit untouched)' do
    allow(AtlasRb::Work).to receive(:find).and_return(AtlasRb::Mash.new(thumbnail: nil))
    allow(Rails.logger).to receive(:warn)

    expect do
      perform_enqueued_jobs { described_class.perform_later(work_id, widths) }
    end.not_to raise_error

    expect(Rails.logger).to have_received(:warn).with(/thumbnail never appeared for work w-dep/)
    expect(DerivativeCreationJob).not_to have_received(:perform_now)
  end

  it 'no-ops on blank widths' do
    allow(AtlasRb::Work).to receive(:find)

    described_class.new.perform(work_id, {})

    expect(AtlasRb::Work).not_to have_received(:find)
    expect(DerivativeCreationJob).not_to have_received(:perform_now)
  end
end
