# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DepositDerivativesJob, type: :job do
  include ActiveJob::TestHelper

  let(:work_id) { 'w-dep' }
  let(:base) { 'http://example.com/iiif/3/gated.jp2' }
  let(:widths) { { small: 149, large: 503 } }

  before { allow(DerivativeCreationJob).to receive(:perform_now) }

  def file_sets_with_service(uri)
    [AtlasRb::Mash.new(noid: 'fs-1', assets: [AtlasRb::Mash.new(use: 'service_file', uri: uri)])]
  end

  it 'recovers the gated base from the service_file Delegate and hands off the widths' do
    allow(AtlasRb::Work).to receive(:file_sets).with(work_id).and_return(file_sets_with_service(base))

    described_class.new.perform(work_id, widths)

    expect(DerivativeCreationJob).to have_received(:perform_now).with(work_id, base, widths: widths)
  end

  it 'raises ServiceNotReady while the service is still in flight (rides retry_on)' do
    allow(AtlasRb::Work).to receive(:file_sets).with(work_id).and_return([])

    expect { described_class.new.perform(work_id, widths) }
      .to raise_error(described_class::ServiceNotReady)
    expect(DerivativeCreationJob).not_to have_received(:perform_now)
  end

  it 'logs and swallows when retries exhaust without a service (deposit untouched)' do
    allow(AtlasRb::Work).to receive(:file_sets).and_return([])
    allow(Rails.logger).to receive(:warn)

    expect do
      perform_enqueued_jobs { described_class.perform_later(work_id, widths) }
    end.not_to raise_error

    expect(Rails.logger).to have_received(:warn).with(/service never appeared for work w-dep/)
    expect(DerivativeCreationJob).not_to have_received(:perform_now)
  end

  it 'no-ops on blank widths' do
    allow(AtlasRb::Work).to receive(:file_sets)

    described_class.new.perform(work_id, {})

    expect(AtlasRb::Work).not_to have_received(:file_sets)
    expect(DerivativeCreationJob).not_to have_received(:perform_now)
  end
end
