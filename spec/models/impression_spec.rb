# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Impression do
  let(:attrs) do
    { noid: 'abc123', action: 'view', ip_address: '10.0.0.1',
      session_id: 's1', referrer: 'direct', user_agent: 'Mozilla/5.0' }
  end

  describe 'validations' do
    it 'is valid with the event-identity triple present' do
      expect(described_class.new(attrs)).to be_valid
    end

    it 'requires noid, action, and ip_address' do
      expect(described_class.new(attrs.merge(noid: nil))).to be_invalid
      expect(described_class.new(attrs.merge(action: nil))).to be_invalid
      expect(described_class.new(attrs.merge(ip_address: nil))).to be_invalid
    end

    it 'does not require the descriptive fields (privacy clients)' do
      expect(described_class.new(attrs.merge(session_id: nil, referrer: nil, user_agent: nil)))
        .to be_valid
    end

    it 'limits action to the known set' do
      expect(described_class.new(attrs.merge(action: 'bogus'))).to be_invalid
      Impression::ACTIONS.each do |action|
        expect(described_class.new(attrs.merge(action:))).to be_valid
      end
    end
  end

  describe 'the 1-hour (noid, action, ip) throttle' do
    it 'accepts the first hit' do
      expect(described_class.create(attrs)).to be_persisted
    end

    it 'rejects a duplicate (noid, action, ip) within the hour' do
      described_class.create!(attrs)

      dup = described_class.new(attrs)
      expect(dup).to be_invalid
      expect(dup.errors[:base]).to include('throttled within the hour')
    end

    it 'accepts again once the window has passed' do
      # Seed an aged row directly, bypassing the throttle + timestamp callbacks.
      aged = attrs.merge(created_at: 2.hours.ago, updated_at: 2.hours.ago)
      cols = aged.keys.join(', ')
      vals = aged.values.map { |v| described_class.connection.quote(v) }.join(', ')
      described_class.connection.execute("INSERT INTO impressions (#{cols}) VALUES (#{vals})")

      expect(described_class.new(attrs)).to be_valid
    end

    it 'does not throttle a different action, ip, or noid' do
      described_class.create!(attrs)

      expect(described_class.new(attrs.merge(action: 'download'))).to be_valid
      expect(described_class.new(attrs.merge(ip_address: '10.0.0.2'))).to be_valid
      expect(described_class.new(attrs.merge(noid: 'other'))).to be_valid
    end
  end
end
