# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SetSentinelApplyJob do
  let(:actor) { '000000004' }
  let(:archives) { 'northeastern:drs:library:archives' }
  let(:media) { 'northeastern:drs:nupd:media' }

  def envelope(read:)
    AtlasRb::Mash.new('read' => read, 'edit' => [], 'edit_users' => [], 'embargo' => nil)
  end

  def stub_contents(*noids, truncated: false)
    allow(SetWorkEnumerator).to receive(:new).and_return(
      instance_double(SetWorkEnumerator,
                      call: SetWorkEnumerator::Result.new(noids: noids, truncated: truncated))
    )
  end

  before do
    allow(AtlasRb::Compilation).to receive(:find).with('set-1')
                                                 .and_return(AtlasRb::Mash.new('id' => 'set-1', 'title' => 'Field Notes'))
    allow(AtlasRb::Work).to receive(:set_derivative_permissions)
  end

  def run
    Current.set(nuid: actor) { described_class.perform_now(set_noid: 'set-1') }
  end

  it 'applies the policy to each work' do
    Sentinel.create!(target_id: 'set-1', policy: { 'master' => [archives] })
    stub_contents('w1')
    allow(AtlasRb::Resource).to receive(:permissions).with('w1').and_return(envelope(read: ['public']))

    run

    expect(AtlasRb::Work).to have_received(:set_derivative_permissions)
      .with('w1', policy: { 'master' => [archives] }, nuid: actor)
  end

  # Atlas refuses a tier naming a group its Work does not grant, so a policy
  # applied as authored would fail on exactly the works most in need of a gate.
  describe 'clamping each tier against its work' do
    it 'narrows a tier to what the work actually grants' do
      Sentinel.create!(target_id: 'set-1', policy: { 'master' => [archives, media] })
      stub_contents('w1')
      allow(AtlasRb::Resource).to receive(:permissions).with('w1').and_return(envelope(read: [archives]))

      run

      expect(AtlasRb::Work).to have_received(:set_derivative_permissions)
        .with('w1', policy: { 'master' => [archives] }, nuid: actor)
    end

    it 'withholds a tier entirely on a private work' do
      Sentinel.create!(target_id: 'set-1', policy: { 'master' => [archives] })
      stub_contents('w1')
      allow(AtlasRb::Resource).to receive(:permissions).with('w1').and_return(envelope(read: []))

      run

      # The only legal tier value on a private work, and the right direction for
      # a gate whose purpose is to withhold.
      expect(AtlasRb::Work).to have_received(:set_derivative_permissions)
        .with('w1', policy: { 'master' => [] }, nuid: actor)
    end

    it 'leaves a tier alone on a public work, since public is the universal audience' do
      Sentinel.create!(target_id: 'set-1', policy: { 'master' => [archives] })
      stub_contents('w1')
      allow(AtlasRb::Resource).to receive(:permissions).with('w1').and_return(envelope(read: ['public']))

      run

      expect(AtlasRb::Work).to have_received(:set_derivative_permissions)
        .with('w1', policy: { 'master' => [archives] }, nuid: actor)
    end

    it 'clamps each tier independently' do
      Sentinel.create!(target_id: 'set-1', policy: { 'master' => [media], 'pdf' => [archives] })
      stub_contents('w1')
      allow(AtlasRb::Resource).to receive(:permissions).with('w1').and_return(envelope(read: [archives]))

      run

      expect(AtlasRb::Work).to have_received(:set_derivative_permissions)
        .with('w1', policy: { 'master' => [], 'pdf' => [archives] }, nuid: actor)
    end
  end

  it 'does nothing when the set has no policy to apply' do
    stub_contents('w1')

    run

    expect(AtlasRb::Work).not_to have_received(:set_derivative_permissions)
    expect(AdminNotice.where(kind: 'set_sentinel_apply')).to be_empty
  end

  it 'does nothing when the set has gone' do
    Sentinel.create!(target_id: 'set-1', policy: { 'master' => [archives] })
    allow(AtlasRb::Compilation).to receive(:find).with('set-1').and_return(nil)

    run

    expect(AtlasRb::Work).not_to have_received(:set_derivative_permissions)
  end

  it 'carries on after one work fails, and names it' do
    Sentinel.create!(target_id: 'set-1', policy: { 'master' => [archives] })
    stub_contents('w1', 'w2')
    allow(AtlasRb::Resource).to receive(:permissions).with('w1').and_return(envelope(read: ['public']))
    allow(AtlasRb::Resource).to receive(:permissions).with('w2').and_return(envelope(read: ['public']))
    allow(AtlasRb::Work).to receive(:set_derivative_permissions)
      .with('w1', anything).and_raise(AtlasRb::ForbiddenError.new('no edit'))

    run

    notice = AdminNotice.find_by(kind: 'set_sentinel_apply')
    expect(notice.payload['failures'].first).to include('w1')
    expect(notice.payload['applied']).to eq(1)
    expect(notice.body).to include('keep their previous access')
  end

  it 'reports a clean run without the problem wording' do
    Sentinel.create!(target_id: 'set-1', policy: { 'master' => [archives] })
    stub_contents('w1')
    allow(AtlasRb::Resource).to receive(:permissions).with('w1').and_return(envelope(read: ['public']))

    run

    notice = AdminNotice.find_by(kind: 'set_sentinel_apply')
    expect(notice.subject).to eq('Derivative access sweep finished')
    expect(notice.body).to include('applied to 1 work', 'Field Notes')
  end
end
