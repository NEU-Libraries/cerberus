# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ResourcePermissions do
  subject(:result) do
    described_class.new(solr_type: 'Work', id: 'abc1234', envelope: { permissions: payload },
                        current_embargo: current_embargo).apply!
  end

  let(:current_embargo) { nil }
  let(:yesterday) { Date.current.yesterday.to_s }

  before { allow(AtlasRb::Resource).to receive(:set_permissions) }

  context 'with a newly entered past embargo' do
    let(:payload) { { read: ['public'], embargo: yesterday } }

    it 'drops the date, keeps the rest of the write, and says so' do
      expect(result.message).to eq(described_class::PAST_EMBARGO_REFUSED)
      expect(AtlasRb::Resource).to have_received(:set_permissions).with('abc1234', { read: ['public'] })
    end
  end

  context 'when the past embargo is the only change' do
    let(:payload) { { embargo: yesterday } }

    it 'skips the write entirely' do
      expect(result.message).to eq(described_class::PAST_EMBARGO_REFUSED)
      expect(AtlasRb::Resource).not_to have_received(:set_permissions)
    end
  end

  # The form re-submits whatever date it was loaded with, so a lapsed embargo
  # must not block every later save of that work's permissions.
  context 'when the past date is the one already stored' do
    let(:current_embargo) { yesterday }
    let(:payload) { { read: ['public'], embargo: yesterday } }

    it 'writes it through untouched' do
      expect(result.level).to be_nil
      expect(AtlasRb::Resource).to have_received(:set_permissions).with('abc1234', payload)
    end
  end

  context 'with a future embargo' do
    let(:payload) { { embargo: Date.current.tomorrow.to_s } }

    it 'writes it through' do
      expect(result.level).to be_nil
      expect(AtlasRb::Resource).to have_received(:set_permissions).with('abc1234', payload)
    end
  end
end
