# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SetSentinelApplyJob do
  let(:actor) { '000000004' }
  let(:archives) { 'northeastern:drs:library:archives' }
  let(:media) { 'northeastern:drs:nupd:media' }

  def envelope(read:, edit: [Permissions::STAFF_EDIT_GROUP])
    AtlasRb::Mash.new('read' => read, 'edit' => edit, 'edit_users' => [], 'embargo' => nil)
  end

  def stub_contents(*noids, truncated: false)
    allow(SetWorkEnumerator).to receive(:new).and_return(
      instance_double(SetWorkEnumerator,
                      call: SetWorkEnumerator::Result.new(noids: noids, truncated: truncated))
    )
  end

  def stub_work(noid, read:, edit: [Permissions::STAFF_EDIT_GROUP])
    allow(AtlasRb::Resource).to receive(:permissions).with(noid).and_return(envelope(read: read, edit: edit))
  end

  def notice
    AdminNotice.find_by(kind: 'set_sentinel_apply')
  end

  before do
    allow(AtlasRb::Compilation).to receive(:find).with('set-1')
                                                 .and_return(AtlasRb::Mash.new('id' => 'set-1', 'title' => 'Field Notes'))
    allow(AtlasRb::Work).to receive(:set_derivative_permissions)
    allow(AtlasRb::Resource).to receive(:set_permissions)
  end

  def run
    Current.set(nuid: actor) { described_class.perform_now(set_noid: 'set-1') }
  end

  it 'applies the policy to each work' do
    Sentinel.create!(target_id: 'set-1', policy: { 'original' => [archives] })
    stub_contents('w1')
    stub_work('w1', read: ['public'])

    run

    expect(AtlasRb::Work).to have_received(:set_derivative_permissions)
      .with('w1', policy: { 'original' => [archives] }, nuid: actor)
  end

  # Atlas refuses a tier naming a group its Work does not grant, so a policy
  # applied as authored would fail on exactly the works most in need of a gate.
  describe 'clamping each tier against its work' do
    it 'narrows a tier to what the work actually grants' do
      Sentinel.create!(target_id: 'set-1', policy: { 'original' => [archives, media] })
      stub_contents('w1')
      stub_work('w1', read: [archives])

      run

      expect(AtlasRb::Work).to have_received(:set_derivative_permissions)
        .with('w1', policy: { 'original' => [archives] }, nuid: actor)
    end

    it 'withholds a tier entirely on a private work' do
      Sentinel.create!(target_id: 'set-1', policy: { 'original' => [archives] })
      stub_contents('w1')
      stub_work('w1', read: [])

      run

      expect(AtlasRb::Work).to have_received(:set_derivative_permissions)
        .with('w1', policy: { 'original' => [] }, nuid: actor)
    end

    it 'clamps against the audience the work has after its ACL changes' do
      Sentinel.create!(target_id: 'set-1', policy: { 'original' => [archives] },
                       work_access: { 'grants' => { 'read' => [media], 'edit' => [] } })
      stub_contents('w1')
      stub_work('w1', read: [archives])

      run

      expect(AtlasRb::Work).to have_received(:set_derivative_permissions)
        .with('w1', policy: { 'original' => [] }, nuid: actor)
    end
  end

  describe 'work access' do
    it 'makes each work public' do
      Sentinel.create!(target_id: 'set-1', policy: {}, work_access: { 'visibility' => 'public' })
      stub_contents('w1')
      stub_work('w1', read: [archives])

      run

      expect(AtlasRb::Resource).to have_received(:set_permissions).with('w1', { 'read' => ['public', archives] },
                                                                        nuid: actor)
      expect(notice.body).to include('1 had their visibility or groups changed')
    end

    it 'replaces each work’s groups' do
      access = { 'visibility' => 'private', 'grants' => { 'read' => [media], 'edit' => [archives] } }
      Sentinel.create!(target_id: 'set-1', policy: {}, work_access: access)
      stub_contents('w1')
      stub_work('w1', read: ['public', archives])

      run

      expect(AtlasRb::Resource).to have_received(:set_permissions)
        .with('w1', { 'read' => [media], 'edit' => [archives] }, nuid: actor)
    end

    it 'leaves the tiers alone when derivatives are not enabled' do
      Sentinel.create!(target_id: 'set-1', policy: {}, derivatives_enabled: false,
                       work_access: { 'visibility' => 'private' })
      stub_contents('w1')
      stub_work('w1', read: ['public'])

      run

      expect(AtlasRb::Work).not_to have_received(:set_derivative_permissions)
    end

    # Restoring a Set's works means knowing what each had; the parents were not
    # touched, so nothing else holds it.
    it 'lists each work it changed with its groups before, and not the ones already matching' do
      Sentinel.create!(target_id: 'set-1', policy: {}, work_access: { 'visibility' => 'private' })
      stub_contents('w1', 'w2')
      stub_work('w1', read: ['public', archives], edit: [Permissions::STAFF_EDIT_GROUP, media])
      stub_work('w2', read: [archives])

      run

      expect(notice.detail(:changed))
        .to eq([{ 'noid' => 'w1', 'read_before' => ['public', archives], 'edit_before' => [media] }])
      expect(notice.payload['changed_count']).to eq(1)
      expect(notice.payload['applied']).to eq(1)
    end

    describe 'a work its collection keeps more restricted' do
      before do
        Sentinel.create!(target_id: 'set-1', policy: {}, work_access: { 'visibility' => 'public' })
        stub_contents('w1', 'w2')
        stub_work('w1', read: [archives])
        stub_work('w2', read: [archives])
        allow(AtlasRb::Resource).to receive(:set_permissions).with('w1', anything, nuid: actor).and_raise(
          AtlasRb::PermissionsError.new('a resource cannot be more visible than its parent',
                                        code: 'visibility_exceeds_parent')
        )
      end

      it 'is named apart from the failures, and the sweep carries on' do
        run

        expect(notice.payload['refused']).to eq(['w1'])
        expect(notice.payload['failures']).to eq([])
        expect(notice.payload['changed_count']).to eq(1)
        expect(notice.subject).to include('problems')
        expect(notice.body).to include('more visible than the collection', 'Work w1')
      end
    end

    it 'names any other refusal as a failure' do
      Sentinel.create!(target_id: 'set-1', policy: {}, work_access: { 'visibility' => 'public' })
      stub_contents('w1')
      stub_work('w1', read: [])
      allow(AtlasRb::Resource).to receive(:set_permissions)
        .and_raise(AtlasRb::PermissionsError.new('no', code: 'something_else'))

      run

      expect(notice.payload['refused']).to eq([])
      expect(notice.payload['failures']).to eq(['Work w1: no'])
    end
  end

  # A re-run would find the changed works already matching, and leave them out
  # of its ledger entry.
  describe 'a lock conflict' do
    before do
      Sentinel.create!(target_id: 'set-1', policy: {}, work_access: { 'visibility' => 'private' })
      stub_contents('w1')
      stub_work('w1', read: ['public'])
    end

    it 'is retried in place, and the work is still listed' do
      calls = 0
      allow(AtlasRb::Resource).to receive(:set_permissions) do
        calls += 1
        raise AtlasRb::StaleResourceError, 'conflict' if calls == 1
      end

      run

      expect(notice.detail(:changed).pluck('noid')).to eq(['w1'])
      expect(notice.detail(:failures)).to eq([])
    end

    it 'is named as a failure once the attempts run out' do
      allow(AtlasRb::Resource).to receive(:set_permissions).and_raise(AtlasRb::StaleResourceError, 'conflict')

      run

      expect(AtlasRb::Resource).to have_received(:set_permissions).exactly(described_class::LOCK_ATTEMPTS).times
      expect(notice.detail(:failures)).to eq(['Work w1: conflict'])
    end
  end

  it 'does nothing when the set has no policy to apply' do
    stub_contents('w1')

    run

    expect(AtlasRb::Work).not_to have_received(:set_derivative_permissions)
    expect(notice).to be_nil
  end

  it 'does nothing when the set has gone' do
    Sentinel.create!(target_id: 'set-1', policy: { 'original' => [archives] })
    allow(AtlasRb::Compilation).to receive(:find).with('set-1').and_return(nil)

    run

    expect(AtlasRb::Work).not_to have_received(:set_derivative_permissions)
  end

  it 'carries on after one work fails, and names it' do
    Sentinel.create!(target_id: 'set-1', policy: { 'original' => [archives] })
    stub_contents('w1', 'w2')
    stub_work('w1', read: ['public'])
    stub_work('w2', read: ['public'])
    allow(AtlasRb::Work).to receive(:set_derivative_permissions)
      .with('w1', anything).and_raise(AtlasRb::ForbiddenError.new('no edit'))

    run

    expect(notice.payload['failures'].first).to include('w1')
    expect(notice.payload['applied']).to eq(1)
    expect(notice.body).to include('keep their previous access')
  end

  it 'counts a work it cannot read as skipped' do
    Sentinel.create!(target_id: 'set-1', policy: {})
    stub_contents('w1')
    allow(AtlasRb::Resource).to receive(:permissions).with('w1').and_return(nil)

    run

    expect(notice.payload['skipped']).to eq(1)
    expect(notice.body).to include('could not be read')
  end

  it 'reports a clean run without the problem wording' do
    Sentinel.create!(target_id: 'set-1', policy: { 'original' => [archives] })
    stub_contents('w1')
    stub_work('w1', read: ['public'])

    run

    expect(notice.subject).to eq('Set permissions sweep finished')
    expect(notice.body).to include('applied to 1 work', 'Field Notes')
  end

  it 'discloses a truncated walk as a problem, and says how to continue' do
    Sentinel.create!(target_id: 'set-1', policy: {})
    stub_contents('w1', truncated: true)
    stub_work('w1', read: ['public'])

    run

    expect(notice.subject).to include('problems')
    expect(notice.body).to include('Run it again to continue')
  end
end
