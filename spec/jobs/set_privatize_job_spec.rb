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
    allow(AtlasRb::Resource).to receive(:set_permissions)
  end

  def run
    Current.set(nuid: actor) { described_class.perform_now(set_noid: 'set-1') }
  end

  it 'strips public from a public work' do
    stub_contents('w1')
    allow(AtlasRb::Resource).to receive(:permissions).with('w1').and_return(envelope(read: ['public']))

    run

    expect(AtlasRb::Resource).to have_received(:set_permissions).with(
      'w1', hash_including('read' => [])
    )
  end

  it 'keeps the group grants a work already carries' do
    stub_contents('w1')
    allow(AtlasRb::Resource).to receive(:permissions)
      .with('w1').and_return(envelope(read: ['public', 'northeastern:drs:library:archives']))

    run

    expect(AtlasRb::Resource).to have_received(:set_permissions).with(
      'w1', hash_including('read' => ['northeastern:drs:library:archives'])
    )
  end

  # The job takes `public` away and changes nothing else, so `read` is the only
  # slot it sends. It still reads the stored envelope first, but for the value —
  # it needs to know what the audience was in order to subtract from it.
  it 'sends the stripped read and nothing else' do
    stub_contents('w1')
    allow(AtlasRb::Resource).to receive(:permissions)
      .with('w1').and_return(envelope(read: ['public'], edit: [staff, 'northeastern:drs:nupd:media'],
                                      edit_users: ['000000011'], embargo: '2027-01-01'))

    run

    expect(AtlasRb::Resource).to have_received(:set_permissions).with('w1', { 'read' => [] })
  end

  it 'leaves a work that is already private alone' do
    stub_contents('w1')
    allow(AtlasRb::Resource).to receive(:permissions)
      .with('w1').and_return(envelope(read: ['northeastern:drs:library:archives']))

    run

    expect(AtlasRb::Resource).not_to have_received(:set_permissions)
  end

  it 'carries on after one work fails, and names it' do
    stub_contents('w1', 'w2')
    allow(AtlasRb::Resource).to receive(:permissions).with('w1').and_raise(AtlasRb::ForbiddenError.new('no edit'))
    allow(AtlasRb::Resource).to receive(:permissions).with('w2').and_return(envelope(read: ['public']))

    run

    expect(AtlasRb::Resource).to have_received(:set_permissions).with('w2', anything)
    notice = AdminNotice.find_by(kind: 'set_privatize')
    expect(notice.payload['failures'].first).to include('w1')
    expect(notice.subject).to include('problems')
  end

  # A lock conflict is transient, so it is retried on the one Work. Not through
  # retry_on: a re-run skips what is already private, and its ledger entry
  # would leave those Works out.
  describe 'a lock conflict' do
    before do
      stub_contents('w1')
      allow(AtlasRb::Resource).to receive(:permissions).with('w1').and_return(envelope(read: ['public']))
    end

    it 'is retried in place, and the Work is still listed' do
      calls = 0
      allow(AtlasRb::Resource).to receive(:set_permissions) do
        calls += 1
        raise AtlasRb::StaleResourceError, 'conflict' if calls == 1
      end

      run

      notice = AdminNotice.find_by(kind: 'set_privatize')
      expect(notice.detail(:changed)).to eq([{ 'noid' => 'w1', 'read_before' => ['public'] }])
      expect(notice.detail(:failures)).to eq([])
    end

    it 'is named as a failure once the attempts run out' do
      allow(AtlasRb::Resource).to receive(:set_permissions).and_raise(AtlasRb::StaleResourceError, 'conflict')

      run

      expect(AtlasRb::Resource).to have_received(:set_permissions).exactly(described_class::LOCK_ATTEMPTS).times
      expect(AdminNotice.find_by(kind: 'set_privatize').detail(:failures)).to eq(['Work w1: conflict'])
    end
  end

  # Making the Set public again does not put a Work's audience back, so the
  # ledger keeps each Work it changed with the audience it had.
  it 'lists each Work it made private with its audience before, and not the ones already private' do
    stub_contents('w1', 'w2')
    allow(AtlasRb::Resource).to receive(:permissions).with('w1')
                                                     .and_return(envelope(read: ['public', 'northeastern:drs:x']))
    allow(AtlasRb::Resource).to receive(:permissions).with('w2').and_return(envelope(read: ['northeastern:drs:x']))

    run

    expect(AdminNotice.find_by(kind: 'set_privatize').detail(:changed))
      .to eq([{ 'noid' => 'w1', 'read_before' => ['public', 'northeastern:drs:x'] }])
  end

  it 'does nothing when the set has gone' do
    allow(AtlasRb::Compilation).to receive(:find).with('set-1').and_return(nil)

    run

    expect(AtlasRb::Resource).not_to have_received(:set_permissions)
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
