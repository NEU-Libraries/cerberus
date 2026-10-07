# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TombstoneBulkJob do
  let(:actor) { '000000004' }

  def solr_doc(noid, klass = 'Work', parent: nil)
    { 'id' => "uuid-#{noid}", 'alternate_ids_ssim' => ["id-#{noid}"], 'internal_resource_tesim' => [klass],
      'title_tsim' => ["Title #{noid}"], 'a_member_of_ssi' => parent && "id-uuid-#{parent}" }
  end

  # The resolve read: whatever is still tombstoned among the selection.
  def stub_tombstoned(*docs)
    response = Blacklight::Solr::Response.new({ 'response' => { 'docs' => docs } }, {},
                                              blacklight_config: CatalogController.blacklight_config)
    allow(Blacklight.default_index).to receive(:search).and_return(response)
  end

  def run(action, noids)
    Current.set(nuid: actor) { described_class.perform_now(action: action, noids: noids) }
  end

  def notice = AdminNotice.where(kind: 'tombstone_bulk').last

  # A tree within the selection: community > collection > work, plus a Work
  # whose parent was not selected. Selected out of order on purpose.
  let(:tree) do
    [solr_doc('w1', parent: 'col'), solr_doc('com', 'Community'),
     solr_doc('col', 'Collection', parent: 'com'), solr_doc('loose', parent: 'elsewhere')]
  end

  it 'restores parents before their children' do
    stub_tombstoned(*tree)
    allow(TombstoneRegistryAction).to receive(:restore).and_return(:ok)

    run('restore', %w[w1 com col loose])

    expect(TombstoneRegistryAction).to have_received(:restore).with('com').ordered
    expect(TombstoneRegistryAction).to have_received(:restore).with('col').ordered
    expect(TombstoneRegistryAction).to have_received(:restore).with('w1').ordered
  end

  it 'deletes children before their containers' do
    stub_tombstoned(*tree)
    allow(TombstoneRegistryAction).to receive(:purge).and_return(:ok)

    run('delete', %w[w1 com col loose])

    expect(TombstoneRegistryAction).to have_received(:purge).with('w1').ordered
    expect(TombstoneRegistryAction).to have_received(:purge).with('col').ordered
    expect(TombstoneRegistryAction).to have_received(:purge).with('com').ordered
    expect(TombstoneRegistryAction).to have_received(:purge).with('loose')
  end

  it 'records the run in one ledger entry and tells the admin' do
    stub_tombstoned(solr_doc('w1'), solr_doc('w2'))
    allow(TombstoneRegistryAction).to receive(:restore).and_return(:ok)
    allow(SystemMessage).to receive(:deliver)

    run('restore', %w[w1 w2])

    expect(SystemMessage).to have_received(:deliver).with(hash_including(to_nuid: actor))

    expect(notice.subject).to eq('Bulk restore: 2 of 2 items restored')
    expect(notice.actor_nuid).to eq(actor)
    expect(notice.detail(:done).pluck('noid')).to contain_exactly('w1', 'w2')
    expect(notice.body).to include('Work w1 — Title w1')
  end

  it 'names each failure and the reason Atlas gave' do
    stub_tombstoned(solr_doc('col', 'Collection'), solr_doc('w1'))
    allow(TombstoneRegistryAction).to receive(:purge).with('col').and_return(:has_children)
    allow(TombstoneRegistryAction).to receive(:purge).with('w1').and_return(:failed)

    run('delete', %w[col w1])

    expect(notice.subject).to eq('Bulk delete: 0 of 2 items deleted')
    expect(notice.detail(:failures)).to contain_exactly('Collection col: still holds members',
                                                        'Work w1: Atlas refused it')
  end

  # A child selected without its tombstoned parent is refused, and the entry
  # has to say how to fix that.
  it 'tells the admin to restore the parent first when Atlas refuses for that reason' do
    stub_tombstoned(solr_doc('w1', parent: 'unselected'))
    allow(TombstoneRegistryAction).to receive(:restore).and_return(:tombstoned_parent)

    run('restore', %w[w1])

    expect(notice.detail(:failures))
      .to eq(['Work w1: its parent is still tombstoned; restore the parent first'])
  end

  # The page can be stale by the time the job runs.
  it 'skips an item that is no longer tombstoned, and says so' do
    stub_tombstoned(solr_doc('w1'))
    allow(TombstoneRegistryAction).to receive(:restore).and_return(:ok)

    run('restore', %w[w1 gone])

    expect(TombstoneRegistryAction).not_to have_received(:restore).with('gone')
    expect(notice.detail(:skipped)).to eq(['gone'])
    expect(notice.body).to include('left alone', 'gone')
  end
end
