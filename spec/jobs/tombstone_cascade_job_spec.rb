# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TombstoneCascadeJob do
  let(:actor) { '000000004' }

  def target(noid, klass = 'Work')
    NarrowingTargets::Target.new(noid: noid, klass: klass, depth: 1)
  end

  def stub_targets(*list)
    allow(TombstoneTargets).to receive(:new).with(noid: 'top', uuid: 'uuid-top').and_return(list)
  end

  def response(status, body = '{}')
    instance_double(Faraday::Response, status: status, body: body, success?: status < 300)
  end

  def run
    Current.set(nuid: actor) do
      described_class.perform_now(noid: 'top', uuid: 'uuid-top', klass: 'Collection',
                                  title: 'Working Papers', reason: 'curator')
    end
  end

  def notice = AdminNotice.where(kind: 'tombstone_cascade').last

  it 'tombstones each target in the walk order, with the one reason' do
    stub_targets(target('w1'), target('child', 'Collection'), target('top', 'Collection'))
    allow(AtlasRb::Resource).to receive(:tombstone).and_return(response(200))

    run

    expect(AtlasRb::Resource).to have_received(:tombstone).with('w1', reason: 'curator').ordered
    expect(AtlasRb::Resource).to have_received(:tombstone).with('child', reason: 'curator').ordered
    expect(AtlasRb::Resource).to have_received(:tombstone).with('top', reason: 'curator').ordered
  end

  # The developer restores from this list, so it must name every item.
  it 'records every NOID it withdrew in one ledger entry' do
    stub_targets(target('w1'), target('top', 'Collection'))
    allow(AtlasRb::Resource).to receive(:tombstone).and_return(response(200))

    run

    expect(notice.subject).to eq('Collection “Working Papers” deleted')
    expect(notice.subject_noid).to eq('top')
    expect(notice.actor_nuid).to eq(actor)
    expect(notice.detail(:tombstoned)).to eq([{ 'noid' => 'w1', 'type' => 'Work' },
                                              { 'noid' => 'top', 'type' => 'Collection' }])
    expect(notice.detail(:reason)).to eq('curator')
    expect(notice.body).to include('2 items deleted', 'ask the development team')
  end

  it 'names what failed, leaves it off the tombstoned list, and says the delete is incomplete' do
    stub_targets(target('w1'), target('top', 'Collection'))
    allow(AtlasRb::Resource).to receive(:tombstone).with('w1', reason: 'curator').and_return(response(500))
    allow(AtlasRb::Resource).to receive(:tombstone).with('top', reason: 'curator')
                                                   .and_return(response(422, '{"code":"has_live_children"}'))

    run

    expect(notice.subject).to eq('Collection “Working Papers” was not fully deleted')
    expect(notice.detail(:tombstoned)).to eq([])
    expect(notice.detail(:failures)).to eq(['Work w1: Atlas answered 500',
                                            'Collection top: still holds a live member'])
  end

  # A lock conflict is transient, and a job-level retry would rebuild the walk
  # without what it had already tombstoned. atlas_rb raises it rather than
  # returning the 409.
  it 'retries one item through a lock conflict without restarting the walk' do
    stub_targets(target('w1'))
    calls = 0
    allow(AtlasRb::Resource).to receive(:tombstone) do
      (calls += 1) == 1 ? raise(AtlasRb::StaleResourceError, 'stale') : response(200)
    end

    run

    expect(AtlasRb::Resource).to have_received(:tombstone).twice
    expect(notice.detail(:tombstoned)).to eq([{ 'noid' => 'w1', 'type' => 'Work' }])
  end

  it 'fails only the locked item when a conflict outlasts the retries, and finishes the walk' do
    stub_targets(target('w1'), target('w2'))
    allow(AtlasRb::Resource).to receive(:tombstone).with('w1', reason: 'curator')
                                                   .and_raise(AtlasRb::StaleResourceError, 'stale')
    allow(AtlasRb::Resource).to receive(:tombstone).with('w2', reason: 'curator').and_return(response(200))

    run

    expect(AtlasRb::Resource).to have_received(:tombstone).with('w1', reason: 'curator')
                                                          .exactly(TombstoneCascadeJob::LOCK_ATTEMPTS).times
    expect(notice.detail(:tombstoned)).to eq([{ 'noid' => 'w2', 'type' => 'Work' }])
    expect(notice.detail(:failures)).to eq(['Work w1: another write held its lock'])
  end
end
