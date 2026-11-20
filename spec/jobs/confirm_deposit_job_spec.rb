# frozen_string_literal: true

require 'rails_helper'

# The depositor's metadata save is what completes an interactive deposit, but only
# once the primary Blob has landed — Atlas builds the METS structMap on complete,
# so completing early would record a structure with no file in it.
RSpec.describe ConfirmDepositJob do
  include ActiveJob::TestHelper

  let(:work_id) { 'w-deposit' }

  before { allow(AtlasRb::Work).to receive(:complete) }

  def file_sets(*roles)
    [AtlasRb::Mash.new(assets: roles.map { |role| AtlasRb::Mash.new(role: role, noid: 'b-1') })]
  end

  it 'completes the Work once the primary file is present' do
    allow(AtlasRb::Work).to receive(:file_sets).with(work_id).and_return(file_sets('original_file'))

    described_class.new.perform(work_id)

    expect(AtlasRb::Work).to have_received(:complete).with(work_id)
  end

  it 'raises PrimaryFileMissing while the primary file is still in flight (rides retry_on)' do
    allow(AtlasRb::Work).to receive(:file_sets).with(work_id).and_return([])

    expect { described_class.new.perform(work_id) }.to raise_error(described_class::PrimaryFileMissing)
    expect(AtlasRb::Work).not_to have_received(:complete)
  end

  # Derivatives arrive before the primary Blob on the slow-conversion paths, so
  # the presence of *some* asset must not be mistaken for the primary one.
  it 'does not complete on a derivative alone' do
    allow(AtlasRb::Work).to receive(:file_sets).with(work_id).and_return(file_sets('service_file', 'small_image'))

    expect { described_class.new.perform(work_id) }.to raise_error(described_class::PrimaryFileMissing)
    expect(AtlasRb::Work).not_to have_received(:complete)
  end

  # A caption landing as the Work completes makes Atlas rebuild the METS twice,
  # and a conflict that outlasts Atlas's own retries arrives as a 409.
  context 'when Atlas reports a lost lock race on complete' do
    before { allow(AtlasRb::Work).to receive(:file_sets).with(work_id).and_return(file_sets('original_file')) }

    it 'retries and completes the Work' do
      calls = 0
      allow(AtlasRb::Work).to receive(:complete).with(work_id) do
        calls += 1
        raise AtlasRb::StaleResourceError.new('stale', resource_id: 'mets-uuid', action: 'complete') if calls == 1
      end

      perform_enqueued_jobs { described_class.perform_later(work_id) }

      expect(AtlasRb::Work).to have_received(:complete).with(work_id).twice
    end

    # The Work is already complete in Atlas by then, so the failed-jobs list is
    # the only place the conflict can surface.
    it 're-raises once the retries run out' do
      allow(AtlasRb::Work).to receive(:complete).and_raise(AtlasRb::StaleResourceError.new('stale', resource_id: 'mets-uuid', action: 'complete'))

      # The test helper wraps a job's exception in Minitest::UnexpectedError.
      expect do
        perform_enqueued_jobs { described_class.perform_later(work_id) }
      end.to raise_error { |e| expect(e.error).to be_a(AtlasRb::StaleResourceError) }
      expect(AtlasRb::Work).to have_received(:complete).exactly(5).times
    end
  end
end
