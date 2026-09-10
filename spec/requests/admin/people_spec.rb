# frozen_string_literal: true

require 'rails_helper'

# Admin People registry: create Person records by NUID, edit display_name / bio
# / orcid, and add/remove community affiliations. atlas_rb and the community
# search are stubbed — these exercise the Cerberus controller/view wiring (and
# the admin gate), not Atlas or Solr.
#
# The create and update examples submit every field the form submits, not just
# the one under assertion. The controller splats its permitted params into an
# atlas_rb keyword signature, and verify_partial_doubles checks a stubbed call
# against the real signature — so a permitted key the gem has dropped fails here
# only if the request actually carries it.
RSpec.describe 'Admin::People', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin_user) do
    User.new(email: 'admin@example.com', password: 'password',
             nuid: '000000004', name: 'User, Admin', role: 'admin')
  end
  # :privileged, but not in the admin group.
  let(:staff_user) do
    User.new(email: 'staff@example.com', password: 'password',
             nuid: '000000006', name: 'Williams, Susan', role: 'privileged',
             groups: ['northeastern:drs:repository:staff'])
  end
  # :privileged + the admin group jointly — the devolved-admin tier (stock
  # pilot user 000000002). Manage people is NOT one of the five devolved
  # surfaces; stays :admin-only.
  let(:delegate_user) do
    User.new(email: 'delegate@example.com', password: 'password',
             nuid: '000000002', name: 'Doe, Jane', role: 'privileged',
             groups: ['northeastern:drs:repository:staff', 'northeastern:drs:repository:admin'])
  end

  let(:person) do
    { 'id' => 'cz8wbpk', 'nuid' => '000000004', 'display_name' => 'David Cliff',
      'bio' => 'Builds the DRS.', 'orcid' => '0000-0002-1825-0097',
      'affiliated_community_ids' => ['jm640df'] }
  end

  describe 'admin gate' do
    it 'forbids non-admin staff' do
      sign_in staff_user
      get admin_people_path
      expect(response).to have_http_status(:forbidden)
    end

    it 'forbids a devolved-admin delegate (this surface stays :admin-only)' do
      sign_in delegate_user
      get admin_people_path
      expect(response).to have_http_status(:forbidden)
    end

    it 'redirects an anonymous visitor to sign in' do
      get admin_people_path
      expect(response).to have_http_status(:redirect)
    end
  end

  context 'as an admin' do
    before { sign_in admin_user }

    describe 'GET /admin/people' do
      it 'lists the curated people' do
        allow(AtlasRb::Person).to receive(:list).and_return([person])

        get admin_people_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('People registry')
        expect(response.body).to include('David Cliff')
        expect(response.body).to include('000000004') # NUID is fine on this admin surface
      end
    end

    describe 'GET /admin/people/new' do
      it 'renders the create form' do
        get new_admin_person_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Register a person')
        expect(response.body).to include('person[nuid]')
      end
    end

    describe 'POST /admin/people' do
      it 'creates a Person and redirects to its edit page' do
        expect(AtlasRb::Person).to receive(:create)
          .with(hash_including(nuid: '000000009', display_name: 'New Person'))
          .and_return({ 'id' => 'new1234', 'display_name' => 'New Person' })

        post admin_people_path, params: { person: { nuid: '000000009', display_name: 'New Person',
                                                    bio: 'Joined this week.',
                                                    orcid: '0000-0002-1825-0097' } }

        expect(response).to redirect_to(edit_admin_person_path('new1234'))
      end
    end

    describe 'GET /admin/people/:noid/edit' do
      it 'renders the identity form and resolves affiliations to community titles' do
        allow(AtlasRb::Person).to receive(:find).with('cz8wbpk', anything).and_return(person)
        allow(AtlasRb::Resource).to receive(:find_many).with(['jm640df'], anything)
                                                       .and_return([AtlasRb::Mash.new('noid'  => 'jm640df',
                                                                                      'title' => 'Communications')])

        get edit_admin_person_path('cz8wbpk')

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('David Cliff')
        expect(response.body).to include('Community affiliations')
        expect(response.body).to include('Communications') # resolved affiliation title
      end

      # find_many drops an id it cannot resolve, so a stale affiliation comes
      # back absent rather than nil-titled. The row must still render.
      it 'falls back to the bare NOID when an affiliation no longer resolves' do
        allow(AtlasRb::Person).to receive(:find).with('cz8wbpk', anything).and_return(person)
        allow(AtlasRb::Resource).to receive(:find_many).and_return([])

        get edit_admin_person_path('cz8wbpk')

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('jm640df')
      end

      it 'resolves every affiliation in one call rather than one per NOID' do
        many = { 'id' => 'cz8wbpk', 'nuid' => '000000004', 'display_name' => 'David Cliff',
                 'affiliated_community_ids' => %w[aaa1111 bbb2222 ccc3333] }
        allow(AtlasRb::Person).to receive(:find).with('cz8wbpk', anything).and_return(many)
        expect(AtlasRb::Resource).to receive(:find_many).once
                                                        .with(%w[aaa1111 bbb2222 ccc3333], anything)
                                                        .and_return([])

        get edit_admin_person_path('cz8wbpk')

        expect(response).to have_http_status(:ok)
      end

      it 'runs the community picker when a query is present' do
        allow(AtlasRb::Person).to receive(:find).and_return(person)
        allow(AtlasRb::Resource).to receive(:find_many)
          .and_return([AtlasRb::Mash.new('noid' => 'jm640df', 'title' => 'Communications')])
        results = instance_double(Blacklight::Solr::Response, documents: [])
        expect(ResourceSearch).to receive(:call)
          .with(hash_including(query: 'art', types: %w[Community])).and_return(results)

        get edit_admin_person_path('cz8wbpk', q: 'art')

        expect(response).to have_http_status(:ok)
      end
    end

    describe 'PATCH /admin/people/:noid' do
      it 'updates the Person details' do
        allow(AtlasRb::Person).to receive(:find).and_return(person)
        expect(AtlasRb::Person).to receive(:update)
          .with('cz8wbpk', hash_including(display_name: 'David C.')).and_return(person)

        patch admin_person_path('cz8wbpk'),
              params: { person: { display_name: 'David C.', bio: 'Builds the DRS.',
                                  orcid: '0000-0002-1825-0097' } }

        expect(response).to redirect_to(edit_admin_person_path('cz8wbpk'))
      end
    end

    describe 'affiliations' do
      before { allow(AtlasRb::Person).to receive(:find).and_return(person) }

      it 'adds an affiliation' do
        expect(AtlasRb::Person).to receive(:add_affiliation).with('cz8wbpk', 'art9999', anything)

        post add_affiliation_admin_person_path('cz8wbpk'), params: { community_id: 'art9999' }

        expect(response).to redirect_to(edit_admin_person_path('cz8wbpk'))
      end

      it 'removes an affiliation' do
        expect(AtlasRb::Person).to receive(:remove_affiliation).with('cz8wbpk', 'jm640df', anything)

        delete remove_affiliation_admin_person_path('cz8wbpk', community_id: 'jm640df')

        expect(response).to redirect_to(edit_admin_person_path('cz8wbpk'))
      end
    end
  end
end
