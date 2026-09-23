# frozen_string_literal: true

require 'rails_helper'

# Discovery must admit whatever Ability lets a user open. Staff reach private
# items through the edit list only, and a depositor's private Work names them
# in no group at all, so a gate on read groups alone hides both. End-to-end over
# the real test Atlas and Solr, which also proves the clause parses.
RSpec.describe 'Edit-equivalent discovery', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:fixtures) { '/home/cerberus/web/spec/fixtures/files' }
  # 000000000–000000006 only: the suite resets Atlas, which mints just those.
  let(:depositor_nuid) { '000000005' }

  let!(:community)  { public_container(AtlasRb::Community, nil) }
  let!(:collection) { public_container(AtlasRb::Collection, community.id) }

  # Written as the admin, attributed to the depositor, then closed so that no
  # read group remains and staff keep only their edit entry.
  let!(:private_work) do
    work = private_deposit
    AtlasRb::Work.complete(work.id, nuid: '000000004')
    work
  end

  def private_deposit
    work = AtlasRb::Work.create(collection.id, "#{fixtures}/work-mods.xml",
                                nuid: '000000004', depositor: depositor_nuid)
    AtlasRb::Resource.set_permissions(work.id, { 'read' => [], 'edit' => [Permissions::STAFF_EDIT_GROUP] },
                                      nuid: '000000004')
    work
  end

  def public_container(klass, parent_id)
    kind = klass.name.demodulize.downcase
    container = klass.create(parent_id, "#{fixtures}/#{kind}-mods.xml", nuid: '000000004')
    AtlasRb::Resource.set_permissions(container.id, { 'read' => ['public'] }, nuid: '000000004')
    container
  end

  # Every spec Work shares the fixture title, so browse newest first to keep
  # this one on the first page, even with parallel workers writing alongside.
  def newest_test_works
    search_catalog_path(q: '', sort: 'date-added', per_page: 100)
  end

  def staff_user
    User.new(email: 'staff@example.com', password: 'password', nuid: '000000002',
             role: 'privileged', groups: [Permissions::STAFF_EDIT_GROUP])
  end

  def reader(nuid, groups: [])
    User.new(email: "#{nuid}@example.com", password: 'password', nuid: nuid, role: 'standard', groups: groups)
  end

  it 'carries no read group but the staff edit group — the shape that exposed the gap' do
    doc = Blacklight.default_index.connection.get(
      'select', params: { q: '*:*', fq: %(alternate_ids_ssim:"id-#{private_work.id}") }
    )['response']['docs'].first
    expect(Array(doc['read_access_group_ssim'])).to be_empty
    expect(Array(doc['edit_access_group_ssim'])).to include(Permissions::STAFF_EDIT_GROUP)
  end

  context 'as non-admin repository staff' do
    before { sign_in staff_user }

    it 'can open it' do
      get work_path(private_work.id)
      expect(response).to have_http_status(:ok)
    end

    it 'finds it in the catalog' do
      get newest_test_works
      expect(response.body).to include(work_path(private_work.id))
    end

    it 'finds it in its collection listing' do
      get collection_path(collection.id)
      expect(response.body).to include(work_path(private_work.id))
    end
  end

  context 'as its depositor' do
    before { sign_in reader(depositor_nuid) }

    it 'finds it in the catalog' do
      get newest_test_works
      expect(response.body).to include(work_path(private_work.id))
    end

    it 'finds an unfinished private deposit in My DRS' do
      accounts = AtlasRb::Mash.new('nuid' => depositor_nuid, 'accounts' => [])
      allow(AtlasRb::User).to receive(:accounts).and_return(accounts)
      unfinished = private_deposit

      get '/my_drs'

      expect(response.body).to include(unfinished.id)
    end
  end

  # A person named in the ACL's edit users, with no group and no deposit.
  context 'as a named editor' do
    let(:editor_nuid) { '000000003' }

    before do
      AtlasRb::Resource.set_permissions(private_work.id, { 'edit_users' => [editor_nuid] }, nuid: '000000004')
      sign_in reader(editor_nuid)
    end

    it 'can open it' do
      get work_path(private_work.id)
      expect(response).to have_http_status(:ok)
    end

    it 'finds it in the catalog' do
      get newest_test_works
      expect(response.body).to include(work_path(private_work.id))
    end

    it 'can reach its edit page' do
      get edit_work_path(private_work.id)
      expect(response).to have_http_status(:ok)
    end
  end

  context 'as a reader in an unrelated group' do
    before { sign_in reader('000000001', groups: ['northeastern:drs:unrelated']) }

    it 'does not find it in the catalog' do
      get newest_test_works
      expect(response.body).not_to include(work_path(private_work.id))
    end

    it 'does not find it in its collection listing' do
      get collection_path(collection.id)
      expect(response.body).not_to include(work_path(private_work.id))
    end
  end

  it 'stays out of the anonymous catalog' do
    get newest_test_works
    expect(response.body).not_to include(work_path(private_work.id))
  end
end
