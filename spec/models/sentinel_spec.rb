# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Sentinel do
  it 'is valid with a target_id and a well-formed, monotonic policy' do
    expect(Sentinel.new(target_id: 'col-1', policy: { 'small' => ['public'], 'large' => ['g:arch'] })).to be_valid
  end

  it 'requires a target_id' do
    expect(Sentinel.new(target_id: nil, policy: {})).not_to be_valid
  end

  it 'requires target_id to be unique' do
    Sentinel.create!(target_id: 'col-1', policy: {})
    expect(Sentinel.new(target_id: 'col-1', policy: {})).not_to be_valid
  end

  describe 'policy shape' do
    it 'rejects an unknown tier' do
      expect(Sentinel.new(target_id: 'c', policy: { 'huge' => ['g:x'] })).not_to be_valid
    end

    it 'rejects a non-array tier value' do
      expect(Sentinel.new(target_id: 'c', policy: { 'large' => 'g:x' })).not_to be_valid
    end
  end

  describe 'monotonicity (audience narrows as resolution grows)' do
    it 'accepts service ⊆ large ⊆ small' do
      policy = { 'small' => ['public'], 'large' => %w[g:arch g:staff], 'service' => ['g:arch'] }
      expect(Sentinel.new(target_id: 'c', policy: policy)).to be_valid
    end

    it 'rejects a higher-res tier more permissive than a lower one' do
      # service public while large is group-gated → service audience wider than large
      policy = { 'large' => ['g:arch'], 'service' => ['public'] }
      expect(Sentinel.new(target_id: 'c', policy: policy)).not_to be_valid
    end

    it 'rejects a higher-res group set not contained in the lower tier' do
      policy = { 'small' => ['g:arch'], 'large' => %w[g:arch g:staff] }
      expect(Sentinel.new(target_id: 'c', policy: policy)).not_to be_valid
    end
  end

  describe '.apply_default' do
    it 'applies the Collection Sentinel to a Work created under it' do
      Sentinel.create!(target_id: 'col-1', policy: { 'large' => ['g:arch'] })
      allow(AtlasRb::Work).to receive(:set_derivative_permissions)

      described_class.apply_default('col-1', 'w-1')

      expect(AtlasRb::Work).to have_received(:set_derivative_permissions)
        .with('w-1', policy: { 'large' => ['g:arch'] }, nuid: nil)
    end

    it 'is a no-op when the Collection has no Sentinel' do
      allow(AtlasRb::Work).to receive(:set_derivative_permissions)

      described_class.apply_default('unmanaged-col', 'w-1')

      expect(AtlasRb::Work).not_to have_received(:set_derivative_permissions)
    end
  end

  describe '#apply_to' do
    it 'pushes only the known tiers to Atlas per-tier gate' do
      sentinel = Sentinel.new(target_id: 'c', policy: { 'large' => ['g:arch'], 'stray' => ['x'] })
      allow(AtlasRb::Work).to receive(:set_derivative_permissions)

      sentinel.apply_to('w-1', nuid: '000000004')

      expect(AtlasRb::Work).to have_received(:set_derivative_permissions)
        .with('w-1', policy: { 'large' => ['g:arch'] }, nuid: '000000004')
    end
  end
end
