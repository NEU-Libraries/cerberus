# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TombstoneRegistryAction do
  def response(status, body = '{}')
    instance_double(Faraday::Response, status: status, body: body, success?: status < 300)
  end

  describe '.restore' do
    it 'is :ok when Atlas accepts' do
      allow(AtlasRb::Admin::Resource).to receive(:restore).with('abc').and_return(response(200))
      expect(described_class.restore('abc')).to eq(:ok)
    end

    it 'is :tombstoned_parent when the parent has to be restored first' do
      allow(AtlasRb::Admin::Resource).to receive(:restore)
        .and_return(response(422, '{"error":"restore the parent first","code":"tombstoned_parent"}'))
      expect(described_class.restore('abc')).to eq(:tombstoned_parent)
    end

    it 'is :failed on any other refusal' do
      allow(AtlasRb::Admin::Resource).to receive(:restore).and_return(response(422))
      expect(described_class.restore('abc')).to eq(:failed)
    end

    # A 409 is a lock conflict, and nothing changed, so the call is repeated.
    it 'retries a lock conflict' do
      allow(AtlasRb::Admin::Resource).to receive(:restore).and_return(response(409), response(200))
      expect(described_class.restore('abc')).to eq(:ok)
      expect(AtlasRb::Admin::Resource).to have_received(:restore).twice
    end

    it 'gives up after the lock attempts' do
      allow(AtlasRb::Admin::Resource).to receive(:restore).and_return(response(409))
      expect(described_class.restore('abc')).to eq(:failed)
      expect(AtlasRb::Admin::Resource).to have_received(:restore).exactly(described_class::LOCK_ATTEMPTS).times
    end

    it 'is :failed on a transport error' do
      allow(AtlasRb::Admin::Resource).to receive(:restore).and_raise(Faraday::ConnectionFailed, 'down')
      expect(described_class.restore('abc')).to eq(:failed)
    end
  end

  describe '.purge' do
    it 'sends the confirm marker and is :ok when Atlas accepts' do
      allow(AtlasRb::Admin::Resource).to receive(:destroy).with('abc', confirm: :i_understand)
                                                          .and_return(response(200))
      expect(described_class.purge('abc')).to eq(:ok)
    end

    it 'is :has_children when a container still holds members' do
      allow(AtlasRb::Admin::Resource).to receive(:destroy).and_return(response(422, '{"code":"has_children"}'))
      expect(described_class.purge('abc')).to eq(:has_children)
    end

    it 'is :failed on a refusal it cannot read' do
      allow(AtlasRb::Admin::Resource).to receive(:destroy).and_return(response(404, 'Not Found'))
      expect(described_class.purge('abc')).to eq(:failed)
    end
  end
end
