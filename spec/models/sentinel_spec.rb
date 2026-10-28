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

  describe 'the extended image ladder (original is the floor)' do
    it 'accepts original ⊆ service ⊆ large ⊆ medium ⊆ small' do
      policy = { 'small' => ['public'], 'medium' => ['public'], 'large' => %w[g:arch g:staff],
                 'service' => ['g:arch'], 'original' => ['g:arch'] }
      expect(Sentinel.new(target_id: 'c', policy: policy)).to be_valid
    end

    it 'rejects original more permissive than service' do
      policy = { 'service' => ['g:arch'], 'original' => %w[g:arch g:staff] }
      expect(Sentinel.new(target_id: 'c', policy: policy)).not_to be_valid
    end
  end

  describe 'independent media (audio/video/pdf gate on their own)' do
    it 'accepts any mix regardless of each other' do
      policy = { 'audio' => ['public'], 'video' => ['g:arch'], 'pdf' => [] }
      expect(Sentinel.new(target_id: 'c', policy: policy)).to be_valid
    end

    it 'does not tie independent media to the image ladder' do
      # original group-gated while audio stays public is fine — different media, no ordering.
      policy = { 'original' => ['g:arch'], 'audio' => ['public'] }
      expect(Sentinel.new(target_id: 'c', policy: policy)).to be_valid
    end
  end

  describe 'container ceiling (tier ⊆ resource_read_groups)' do
    it 'is skipped when no container read groups are supplied' do
      expect(Sentinel.new(target_id: 'c', policy: { 'small' => ['public'] })).to be_valid
    end

    it 'accepts tiers within the container audience' do
      sentinel = Sentinel.new(target_id: 'c', policy: { 'original' => ['g:arch'] })
      sentinel.resource_read_groups = %w[g:arch g:staff]
      expect(sentinel).to be_valid
    end

    it 'refuses a tier more visible than a restricted container' do
      sentinel = Sentinel.new(target_id: 'c', policy: { 'small' => ['public'] })
      sentinel.resource_read_groups = ['g:staff']
      expect(sentinel).not_to be_valid
    end

    it 'treats a public container as the universal ceiling' do
      sentinel = Sentinel.new(target_id: 'c', policy: { 'small' => ['public'], 'original' => ['g:arch'] })
      sentinel.resource_read_groups = ['public']
      expect(sentinel).to be_valid
    end
  end

  describe '#tier_policy' do
    it 'keeps the extended vocabulary and drops stray keys' do
      sentinel = Sentinel.new(target_id: 'c',
                              policy:    { 'original' => ['g:arch'], 'pdf' => ['public'], 'nope' => ['x'] })
      expect(sentinel.tier_policy).to eq('original' => ['g:arch'], 'pdf' => ['public'])
    end
  end

  def envelope(read:, edit: [Permissions::STAFF_EDIT_GROUP])
    AtlasRb::Mash.new('read' => read, 'edit' => edit, 'edit_users' => [], 'embargo' => nil)
  end

  let(:archives) { 'northeastern:drs:library:archives' }
  let(:media) { 'northeastern:drs:nupd:media' }

  describe '.apply_default' do
    before do
      allow(AtlasRb::Work).to receive(:set_derivative_permissions)
      allow(AtlasRb::Resource).to receive(:set_permissions)
      allow(AtlasRb::Resource).to receive(:permissions).with('w-1').and_return(envelope(read: ['public']))
    end

    it 'applies the Collection Sentinel to a Work created under it' do
      Sentinel.create!(target_id: 'col-1', policy: { 'large' => ['g:arch'] })

      described_class.apply_default('col-1', 'w-1')

      expect(AtlasRb::Work).to have_received(:set_derivative_permissions)
        .with('w-1', policy: { 'large' => ['g:arch'] }, nuid: nil)
    end

    it 'is a no-op when the Collection has no Sentinel' do
      described_class.apply_default('unmanaged-col', 'w-1')

      expect(AtlasRb::Work).not_to have_received(:set_derivative_permissions)
    end

    it 'leaves the ACL the depositor chose when told to skip work access' do
      Sentinel.create!(target_id: 'col-1', policy: {}, work_access: { 'visibility' => 'private' })

      described_class.apply_default('col-1', 'w-1', work_access: false)

      expect(AtlasRb::Resource).not_to have_received(:set_permissions)
      expect(AtlasRb::Work).to have_received(:set_derivative_permissions).with('w-1', policy: {}, nuid: nil)
    end
  end

  describe '#apply_to' do
    before do
      allow(AtlasRb::Work).to receive(:set_derivative_permissions)
      allow(AtlasRb::Resource).to receive(:set_permissions)
    end

    def apply(sentinel, read:, edit: [Permissions::STAFF_EDIT_GROUP])
      allow(AtlasRb::Resource).to receive(:permissions).with('w-1').and_return(envelope(read: read, edit: edit))
      sentinel.apply_to('w-1', nuid: '000000004')
    end

    it 'pushes only the known tiers to Atlas per-tier gate' do
      apply(Sentinel.new(target_id: 'c', policy: { 'large' => ['g:arch'], 'stray' => ['x'] }), read: ['public'])

      expect(AtlasRb::Work).to have_received(:set_derivative_permissions)
        .with('w-1', policy: { 'large' => ['g:arch'] }, nuid: '000000004')
    end

    it 'does nothing to a Work it cannot read' do
      allow(AtlasRb::Resource).to receive(:permissions).with('w-1').and_return(nil)

      expect(Sentinel.new(target_id: 'c', policy: {}).apply_to('w-1')).to be_nil
      expect(AtlasRb::Work).not_to have_received(:set_derivative_permissions)
    end

    it 'leaves the ACL alone without a work access slot' do
      result = apply(Sentinel.new(target_id: 'c', policy: {}), read: ['public', archives])

      expect(AtlasRb::Resource).not_to have_received(:set_permissions)
      expect(result.acl_changed).to be(false)
    end

    it 'makes a Work public and keeps its groups' do
      sentinel = Sentinel.new(target_id: 'c', policy: {}, work_access: { 'visibility' => 'public' })
      apply(sentinel, read: [archives])

      expect(AtlasRb::Resource).to have_received(:set_permissions)
        .with('w-1', { 'read' => ['public', archives] }, nuid: '000000004')
    end

    it 'makes a Work private and keeps its groups' do
      sentinel = Sentinel.new(target_id: 'c', policy: {}, work_access: { 'visibility' => 'private' })
      apply(sentinel, read: ['public', archives])

      expect(AtlasRb::Resource).to have_received(:set_permissions)
        .with('w-1', { 'read' => [archives] }, nuid: '000000004')
    end

    it 'replaces the groups and keeps the visibility it does not name' do
      access = { 'grants' => { 'read' => [media], 'edit' => [archives] } }
      apply(Sentinel.new(target_id: 'c', policy: {}, work_access: access), read: ['public', archives])

      expect(AtlasRb::Resource).to have_received(:set_permissions)
        .with('w-1', { 'read' => ['public', media], 'edit' => [archives] }, nuid: '000000004')
    end

    it 'skips the write when the Work already matches, ignoring the staff edit group' do
      access = { 'visibility' => 'private', 'grants' => { 'read' => [archives], 'edit' => [] } }
      result = apply(Sentinel.new(target_id: 'c', policy: {}, work_access: access), read: [archives])

      expect(AtlasRb::Resource).not_to have_received(:set_permissions)
      expect(result.acl_changed).to be(false)
    end

    it 'records the audience it replaced, without the staff group' do
      sentinel = Sentinel.new(target_id: 'c', policy: {}, work_access: { 'visibility' => 'private' })
      result = apply(sentinel, read: ['public'], edit: [Permissions::STAFF_EDIT_GROUP, archives])

      expect(result.to_h).to eq(acl_changed: true, read_before: ['public'], edit_before: [archives])
    end

    # Atlas refuses a tier naming a group its Work does not grant.
    it 'clamps the tiers against the audience the Work has after the write' do
      sentinel = Sentinel.new(target_id: 'c', policy: { 'original' => ['public'], 'pdf' => [media] },
                              work_access: { 'visibility' => 'private' })
      apply(sentinel, read: ['public', archives])

      expect(AtlasRb::Work).to have_received(:set_derivative_permissions)
        .with('w-1', policy: { 'original' => [archives], 'pdf' => [] }, nuid: '000000004')
    end

    it 'leaves the tiers alone when derivatives are not enabled' do
      sentinel = Sentinel.new(target_id: 'c', policy: {}, derivatives_enabled: false,
                              work_access: { 'visibility' => 'public' })
      apply(sentinel, read: [])

      expect(AtlasRb::Resource).to have_received(:set_permissions)
      expect(AtlasRb::Work).not_to have_received(:set_derivative_permissions)
    end
  end

  describe 'work access shape' do
    def sentinel(access)
      Sentinel.new(target_id: 'c', policy: {}, work_access: access)
    end

    it 'accepts a visibility, grants, or both' do
      expect(sentinel({ 'visibility' => 'public' })).to be_valid
      expect(sentinel({ 'grants' => { 'read' => [archives], 'edit' => [] } })).to be_valid
    end

    it 'stores an empty slot as none' do
      record = sentinel({})
      record.valid?
      expect(record.work_access).to be_nil
    end

    it 'rejects an unknown visibility, key or ability' do
      expect(sentinel({ 'visibility' => 'open' })).not_to be_valid
      expect(sentinel({ 'embargo' => '2030-01-01' })).not_to be_valid
      expect(sentinel({ 'grants' => { 'own' => [archives] } })).not_to be_valid
    end

    it 'refuses public as a group grant' do
      expect(sentinel({ 'grants' => { 'read' => ['public'] } })).not_to be_valid
    end
  end

  describe 'work access ceiling (Work ⊆ resource_read_groups)' do
    def sentinel(access, ceiling)
      Sentinel.new(target_id: 'c', policy: {}, work_access: access).tap { |s| s.resource_read_groups = ceiling }
    end

    it 'refuses public Works in a restricted collection' do
      expect(sentinel({ 'visibility' => 'public' }, [archives])).not_to be_valid
    end

    it 'refuses a read group the collection does not grant' do
      expect(sentinel({ 'grants' => { 'read' => [media] } }, [archives])).not_to be_valid
    end

    it 'accepts anything under a public collection' do
      expect(sentinel({ 'visibility' => 'public', 'grants' => { 'read' => [media] } }, ['public'])).to be_valid
    end
  end

  describe '#clamp_to!' do
    it 'drops a public visibility and narrows the grants under a restricted container' do
      record = Sentinel.create!(target_id: 'c', policy: { 'small' => ['public'] },
                                work_access: { 'visibility' => 'public',
                                               'grants'     => { 'read' => [archives, media], 'edit' => [media] } })

      record.clamp_to!([archives])

      expect(record.reload.policy).to eq('small' => [archives])
      expect(record.work_access).to eq('grants' => { 'read' => [archives], 'edit' => [media] })
    end

    it 'writes nothing when the Sentinel already fits' do
      record = Sentinel.create!(target_id: 'c', policy: { 'small' => [archives] },
                                work_access: { 'visibility' => 'private' })

      expect { record.clamp_to!([archives]) }.not_to(change { record.reload.updated_at })
    end
  end
end
