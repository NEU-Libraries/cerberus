# frozen_string_literal: true

require 'rails_helper'

# The depositor's metadata save is what completes an interactive deposit, but only
# once the primary Blob has landed — Atlas builds the METS structMap on complete,
# so completing early would record a structure with no file in it.
RSpec.describe ConfirmDepositJob do
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
end
