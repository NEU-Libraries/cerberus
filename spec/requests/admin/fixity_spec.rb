# frozen_string_literal: true

require 'rails_helper'

# The admin fixity report, over the real test Atlas and Solr. The suite cannot
# record a check, so a fresh Work is the one state it can seed: never verified.
# spec/models/fixity_search_builder_spec.rb covers the other two lists.
RSpec.describe 'Admin fixity report', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:fixtures) { '/home/cerberus/web/spec/fixtures/files' }

  let(:admin) do
    User.new(email: 'admin@example.com', password: 'password', nuid: '000000004', role: 'admin')
  end
  let(:delegate) do
    User.new(email: 'delegate@example.com', password: 'password', nuid: '000000002', role: 'privileged',
             groups: [Permissions::STAFF_EDIT_GROUP, 'northeastern:drs:repository:admin'])
  end

  describe 'the authorization gate' do
    it 'admits an admin' do
      sign_in admin
      get admin_fixity_path
      expect(response).to have_http_status(:ok)
    end

    # Gated discovery would show the tier a partial list that reads as healthy.
    it 'refuses the devolved-admin tier' do
      sign_in delegate
      get admin_fixity_path
      expect(response).to have_http_status(:forbidden)
    end

    it 'refuses an anonymous visitor' do
      get admin_fixity_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  context 'as an admin' do
    before { sign_in admin }

    let!(:work) do
      community = AtlasRb::Community.create(nil, "#{fixtures}/community-mods.xml", nuid: '000000004')
      collection = AtlasRb::Collection.create(community.id, "#{fixtures}/collection-mods.xml", nuid: '000000004')
      created = AtlasRb::Work.create(collection.id, "#{fixtures}/work-mods.xml", nuid: '000000004')
      AtlasRb::Work.complete(created.id, nuid: '000000004')
      created
    end

    it 'lists a Work with no recorded check as never verified, linked to its Health tab' do
      get admin_fixity_path(state: 'never')

      expect(response.body).to include('Never verified', edit_work_path(work.id, tab: 'health'))
    end

    it 'keeps a never-checked Work off the failed and overdue lists' do
      %w[failed overdue].each do |state|
        get admin_fixity_path(state: state)
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include(edit_work_path(work.id, tab: 'health'))
      end
    end

    it 'falls back to the failed list for an unknown state' do
      get admin_fixity_path(state: 'nonsense')

      expect(response).to have_http_status(:ok)
      expect(response.body[/<a[^>]*aria-current="page"[^>]*>/]).to include(admin_fixity_path(state: 'failed'))
    end
  end
end
