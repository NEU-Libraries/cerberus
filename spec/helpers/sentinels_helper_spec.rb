# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SentinelsHelper do
  describe '#derivative_tier_meta' do
    it 'returns the label and resolution note for a known tier' do
      expect(helper.derivative_tier_meta('service')).to eq(label: 'Service', note: 'Full-resolution deep-zoom')
    end

    it 'covers the master and independent-media tiers' do
      expect(helper.derivative_tier_meta('master')).to eq(label: 'Master / original', note: 'Full-resolution source file')
      expect(helper.derivative_tier_meta('pdf')).to eq(label: 'PDF', note: 'Downloadable PDF rendition')
    end
  end

  describe '#derivative_tier_form_state' do
    it 'reads Public for an absent Sentinel' do
      expect(helper.derivative_tier_form_state(nil, 'large')).to eq(mode: 'public', groups: [])
    end

    it 'reads Public for a tier explicitly set to public' do
      sentinel = Sentinel.new(policy: { 'small' => ['public'] })
      expect(helper.derivative_tier_form_state(sentinel, 'small')).to eq(mode: 'public', groups: [])
    end

    it 'reads Restricted with the tier groups checked' do
      sentinel = Sentinel.new(policy: { 'large' => %w[g:arch g:staff] })
      expect(helper.derivative_tier_form_state(sentinel, 'large')).to eq(mode: 'restrict', groups: %w[g:arch g:staff])
    end

    it 'reads Restricted (to nobody) for an explicit empty group list' do
      sentinel = Sentinel.new(policy: { 'service' => [] })
      expect(helper.derivative_tier_form_state(sentinel, 'service')).to eq(mode: 'restrict', groups: [])
    end
  end
end
