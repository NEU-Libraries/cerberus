# frozen_string_literal: true

require 'rails_helper'

# An unfinished deposit — one no depositor has confirmed — is a placeholder: it
# carries the uploaded filename as its title and no subjects. It also inherits its
# parent's audience, so read gating alone leaves one deposited into a public
# collection fully public. End-to-end over the real test Atlas: a Work created but
# never completed is exactly what the deposit form leaves behind between its two
# steps.
RSpec.describe 'Unfinished deposits', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:fixtures) { '/home/cerberus/web/spec/fixtures/files' }
  # 000000000–000000006 only: the suite resets Atlas, which mints just those. The
  # group-gated personas come from Cerberus's own seed task and are unknown
  # principals here, which Atlas rejects with a 400.
  let(:depositor_nuid) { '000000005' }

  let!(:community)  { public_container(AtlasRb::Community, nil) }
  let!(:collection) { public_container(AtlasRb::Collection, community.id) }

  # Created and NOT completed — the state between the deposit form's two steps.
  # Written as the admin, attributed to the depositor: a standard depositor has no
  # rights in this collection, and the depositor is what the gate keys on.
  let!(:unfinished) do
    work = AtlasRb::Work.create(collection.id, "#{fixtures}/work-mods.xml",
                                nuid: '000000004', depositor: depositor_nuid)
    AtlasRb::Work.metadata(work.id, { 'permissions' => { 'read' => ['public'] } }, nuid: '000000004')
    work
  end

  def staff_user
    User.new(email: 'staff@example.com', password: 'password', nuid: '000000002',
             role: 'privileged', groups: [Permissions::STAFF_EDIT_GROUP])
  end

  def reader(nuid)
    User.new(email: "#{nuid}@example.com", password: 'password', nuid: nuid, role: 'standard', groups: [])
  end

  def public_container(klass, parent_id)
    kind = klass.name.demodulize.downcase
    container = klass.create(parent_id, "#{fixtures}/#{kind}-mods.xml", nuid: '000000004')
    klass.metadata(container.id, { 'permissions' => { 'read' => ['public'] } }, nuid: '000000004')
    container
  end

  it 'is confirmed unfinished and publicly readable — the two facts that make the gate necessary' do
    expect(AtlasRb::Work.find(unfinished.id).in_progress).to be true
  end

  describe 'its own page' do
    it '404s an anonymous visitor' do
      get work_path(unfinished.id)
      expect(response).to have_http_status(:not_found)
    end

    it '404s a signed-in reader who did not deposit it' do
      sign_in reader('000000001')
      get work_path(unfinished.id)
      expect(response).to have_http_status(:not_found)
    end

    it 'renders for repository staff, who curate unfinished deposits' do
      sign_in staff_user
      get work_path(unfinished.id)
      expect(response).to have_http_status(:ok)
    end

    it 'renders for its own depositor, the one person who can finish it' do
      sign_in reader(depositor_nuid)
      get work_path(unfinished.id)
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'discovery' do
    it 'is absent from the anonymous catalog' do
      get search_catalog_path(q: 'Test Work')
      expect(response.body).not_to include(work_path(unfinished.id))
    end

    it 'is absent from its collection listing for an anonymous visitor' do
      get collection_path(collection.id)
      expect(response.body).not_to include(work_path(unfinished.id))
    end

    it 'is listed for repository staff' do
      sign_in staff_user
      get collection_path(collection.id)
      expect(response.body).to include(work_path(unfinished.id))
    end
  end

  # Completion is the depositor's act now, so the same Work becomes public the
  # moment it is confirmed — nothing else about it changes.
  it 'becomes publicly visible once completed' do
    AtlasRb::Work.complete(unfinished.id, nuid: '000000004')

    get work_path(unfinished.id)

    expect(response).to have_http_status(:ok)
  end
end
