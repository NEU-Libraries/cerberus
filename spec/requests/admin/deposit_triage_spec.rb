# frozen_string_literal: true

require 'rails_helper'

# The admin triage registry: the two states a deposit gets stuck in, on one
# surface. End-to-end over the real test Atlas and Solr, because the whole point
# is that these Works are the ones ordinary discovery hides — a stubbed search
# would not prove the builder undoes the right exclusion.
RSpec.describe 'Admin deposit triage', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:fixtures) { '/home/cerberus/web/spec/fixtures/files' }

  let(:admin) do
    User.new(email: 'admin@example.com', password: 'password', nuid: '000000004', role: 'admin')
  end
  # :privileged + the admin group — the devolved-admin tier this surface admits.
  let(:delegate) do
    User.new(email: 'delegate@example.com', password: 'password', nuid: '000000002', role: 'privileged',
             groups: [Permissions::STAFF_EDIT_GROUP, 'northeastern:drs:repository:admin'])
  end
  # :privileged WITHOUT the admin group — the negative control.
  let(:staff) do
    User.new(email: 'staff@example.com', password: 'password', nuid: '000000006', role: 'privileged',
             groups: [Permissions::STAFF_EDIT_GROUP])
  end

  let!(:community) { AtlasRb::Community.create(nil, "#{fixtures}/community-mods.xml", nuid: '000000004') }
  let!(:collection) do
    AtlasRb::Collection.create(community.id, "#{fixtures}/collection-mods.xml", nuid: '000000004')
  end

  # Created and never completed: the state the deposit form leaves between steps.
  let!(:unconfirmed) do
    AtlasRb::Work.create(collection.id, "#{fixtures}/work-mods.xml", nuid: '000000004')
  end

  # Completed, then flagged: an enrichment job gave up on a finished deposit.
  let!(:flagged) do
    work = AtlasRb::Work.create(collection.id, "#{fixtures}/work-mods.xml", nuid: '000000004')
    AtlasRb::Work.complete(work.id, nuid: '000000004')
    AtlasRb::Work.mark_incomplete(work.id, reason: IncompleteReasons::THUMBNAILS, nuid: '000000004')
    work
  end

  describe 'the authorization gate' do
    it 'admits an admin' do
      sign_in admin
      get admin_deposit_triage_path
      expect(response).to have_http_status(:ok)
    end

    it 'admits the devolved-admin tier' do
      sign_in delegate
      get admin_deposit_triage_path
      expect(response).to have_http_status(:ok)
    end

    it 'refuses staff without the admin group' do
      sign_in staff
      get admin_deposit_triage_path
      expect(response).to have_http_status(:forbidden)
    end

    it 'refuses an anonymous visitor' do
      get admin_deposit_triage_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  context 'as an admin' do
    before { sign_in admin }

    it 'lists an unconfirmed deposit by default, which ordinary discovery hides' do
      get admin_deposit_triage_path

      expect(response.body).to include('Waiting on a depositor')
      expect(response.body).to include(metadata_work_path(unconfirmed.id))
    end

    it 'lists a flagged work on the other tab, with what is missing' do
      get admin_deposit_triage_path(state: 'incomplete')

      expect(response.body).to include('No thumbnail was made')
      expect(response.body).to include(work_path(flagged.id))
    end

    # Each Work belongs on one list only, and on the one whose action is the next
    # thing that has to happen: an unconfirmed deposit needs finishing before
    # anybody worries about its thumbnails.
    it 'keeps the two lists disjoint' do
      get admin_deposit_triage_path(state: 'incomplete')
      expect(response.body).not_to include(metadata_work_path(unconfirmed.id))

      get admin_deposit_triage_path
      expect(response.body).not_to include(work_path(flagged.id))
    end

    it 'falls back to the unconfirmed list for an unknown state' do
      get admin_deposit_triage_path(state: 'nonsense')

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(metadata_work_path(unconfirmed.id))
    end

    it 'offers the surface from the admin dashboard' do
      get admin_root_path
      expect(response.body).to include(admin_deposit_triage_path)
    end
  end
end
