# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SentinelsHelper do
  describe '#derivative_tier_meta' do
    it 'returns the label and resolution note for a known tier' do
      expect(helper.derivative_tier_meta('service')).to eq(label: 'Service', note: 'Full-resolution deep-zoom')
    end

    it 'covers the original and independent-media tiers' do
      expect(helper.derivative_tier_meta('original')).to eq(label: 'Original', note: 'Full-resolution source file')
      expect(helper.derivative_tier_meta('pdf')).to eq(label: 'PDF', note: 'Downloadable PDF file')
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

  describe '#sentinel_grant_rows' do
    it 'labels each saved grant from the registry, falling back to the raw id' do
      sentinel = Sentinel.new(work_access: { 'grants' => { 'read' => %w[g:arch], 'edit' => %w[g:gone] } })
      rows = helper.sentinel_grant_rows(sentinel, [['g:arch', 'Archives']])

      expect(rows.map { |row| [row.group_id, row.label, row.ability, row.revocable?] })
        .to eq([['g:arch', 'Archives', 'read', true], ['g:gone', 'g:gone', 'edit', true]])
    end

    it 'is empty without grants' do
      expect(helper.sentinel_grant_rows(nil, [])).to eq([])
    end
  end

  describe '#sentinel_apply_summary' do
    it 'names each part the sweep will change' do
      sentinel = Sentinel.new(work_access: { 'visibility' => 'private', 'grants' => { 'read' => %w[g:a], 'edit' => [] } })

      expect(helper.sentinel_apply_summary(sentinel)).to eq(
        ['Every work is made private.',
         "Every work's group grants are replaced with the 1 grant saved here.",
         "Every work's derivative access is set to the policy saved here."]
      )
    end

    it 'says outright when a replacement removes every group' do
      sentinel = Sentinel.new(derivatives_enabled: false, work_access: { 'grants' => { 'read' => [], 'edit' => [] } })
      expect(helper.sentinel_apply_summary(sentinel)).to eq(['Every group grant is removed from every work.'])
    end

    it 'is empty when every part is left alone' do
      expect(helper.sentinel_apply_summary(Sentinel.new(derivatives_enabled: false))).to eq([])
    end
  end

  describe '#sentinel_widens?' do
    it 'is true only for a public visibility' do
      expect(helper.sentinel_widens?(Sentinel.new(work_access: { 'visibility' => 'public' }))).to be(true)
      expect(helper.sentinel_widens?(Sentinel.new(work_access: { 'visibility' => 'private' }))).to be(false)
      expect(helper.sentinel_widens?(nil)).to be(false)
    end
  end
end
