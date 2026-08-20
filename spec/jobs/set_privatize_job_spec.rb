# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SetPrivatizeJob do
  let(:actor) { '000000004' }
  let(:staff) { 'northeastern:drs:repository:staff' }

  def envelope(read:, edit: [staff], edit_users: [], embargo: nil)
    AtlasRb::Mash.new('read' => read, 'edit' => edit, 'edit_users' => edit_users,
                      'embargo' => embargo, 'depositor' => '000000010')
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
    allow(AtlasRb::Work).to receive(:metadata)
  end

  def run
    Current.set(nuid: actor) { described_class.perform_now(set_noid: 'set-1') }
  end

  it 'strips public from a public work' do
    stub_contents('w1')
    allow(AtlasRb::Resource).to receive(:permissions).with('w1').and_return(envelope(read: ['public']))

    run

    expect(AtlasRb::Work).to have_received(:metadata).with(
      'w1', hash_including('permissions' => hash_including('read' => []))
    )
  end

  it 'keeps the group grants a work already carries' do
    stub_contents('w1')
    allow(AtlasRb::Resource).to receive(:permissions)
      .with('w1').and_return(envelope(read: ['public', 'northeastern:drs:library:archives']))

    run

    expect(AtlasRb::Work).to have_received(:metadata).with(
      'w1', hash_including('permissions' => hash_including('read' => ['northeastern:drs:library:archives']))
    )
  end

  # The whole-envelope rule: Atlas assigns edit/edit_users/embargo
  # unconditionally, so a payload carrying read alone blanks them.
  it 'sends the whole envelope, not just read' do
    stub_contents('w1')
    allow(AtlasRb::Resource).to receive(:permissions)
      .with('w1').and_return(envelope(read: ['public'], edit: [staff, 'northeastern:drs:nupd:media'],
                                      edit_users: ['000000011'], embargo: '2027-01-01'))

    run

    expect(AtlasRb::Work).to have_received(:metadata).with(
      'w1', { 'permissions' => { 'embargo' => '2027-01-01', 'read' => [],
                                 'edit' => [staff, 'northeastern:drs:nupd:media'],
                                 'edit_users' => ['000000011'] } }
    )
  end

  it 'leaves a work that is already private alone' do
    stub_contents('w1')
    allow(AtlasRb::Resource).to receive(:permissions)
      .with('w1').and_return(envelope(read: ['northeastern:drs:library:archives']))

    run

    expect(AtlasRb::Work).not_to have_received(:metadata)
  end

  it 'carries on after one work fails, and names it' do
    stub_contents('w1', 'w2')
    allow(AtlasRb::Resource).to receive(:permissions).with('w1').and_raise(AtlasRb::ForbiddenError.new('no edit'))
    allow(AtlasRb::Resource).to receive(:permissions).with('w2').and_return(envelope(read: ['public']))

    run

    expect(AtlasRb::Work).to have_received(:metadata).with('w2', anything)
    notice = AdminNotice.find_by(kind: 'set_privatize')
    expect(notice.payload['failures'].first).to include('w1')
    expect(notice.subject).to include('problems')
  end

  # A lock conflict is transient and the sweep is idempotent, so it belongs to
  # retry_on rather than to the report. retry_on handles the exception, so
  # perform_now never propagates it — the observable effect is that no notice is
  # written, because perform aborted before it could report.
  it 'does not record a stale-lock conflict as a permanent failure' do
    stub_contents('w1')
    allow(AtlasRb::Resource).to receive(:permissions).with('w1').and_raise(AtlasRb::StaleResourceError.new('conflict'))

    expect { run }.not_to change(AdminNotice, :count)
  end

  it 'does nothing when the set has gone' do
    allow(AtlasRb::Compilation).to receive(:find).with('set-1').and_return(nil)

    run

    expect(AtlasRb::Work).not_to have_received(:metadata)
  end

  describe 'the report' do
    it 'counts what it changed and what was already private' do
      stub_contents('w1', 'w2')
      allow(AtlasRb::Resource).to receive(:permissions).with('w1').and_return(envelope(read: ['public']))
      allow(AtlasRb::Resource).to receive(:permissions).with('w2').and_return(envelope(read: []))

      run

      notice = AdminNotice.find_by(kind: 'set_privatize')
      expect(notice.payload['privatized']).to eq(1)
      expect(notice.payload['already_private']).to eq(1)
      expect(notice.body).to include('1 work made private', 'Field Notes')
    end

    it 'discloses a truncated walk as a problem, and says how to continue' do
      stub_contents('w1', truncated: true)
      allow(AtlasRb::Resource).to receive(:permissions).with('w1').and_return(envelope(read: ['public']))

      run

      notice = AdminNotice.find_by(kind: 'set_privatize')
      expect(notice.subject).to include('problems')
      expect(notice.body).to include('Run it again to continue')
    end

    it 'records the notice even with no actor to message' do
      stub_contents('w1')
      allow(AtlasRb::Resource).to receive(:permissions).with('w1').and_return(envelope(read: ['public']))

      described_class.perform_now(set_noid: 'set-1')

      expect(AdminNotice.find_by(kind: 'set_privatize')).to be_present
    end
  end
end
