# frozen_string_literal: true

require 'rails_helper'

# End-to-end over the real test Atlas: compilations are created through
# AtlasRb against atlas-test (the stock 000000002 / 000000004 users exist
# there), and the contents resolution runs against the same Solr the app
# uses. SetResolver's recipe semantics are specced in detail at the service
# level; this file covers the HTTP surface: gates, CRUD, the recipe
# mutations, and the show-page render.
RSpec.describe 'Sets', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:curator) do
    User.new(email: 'dps@example.com', password: 'password',
             nuid: '000000002', role: 'privileged',
             groups: ['northeastern:drs:repository:staff'])
  end
  let(:guest_user) do
    User.new(email: 'guest@example.com', password: 'password',
             nuid: '000000001', role: 'guest', groups: [])
  end
  let(:other_user) do
    User.new(email: 'loader@example.com', password: 'password',
             nuid: '000000003', role: 'loader',
             groups: ['northeastern:drs:repository:loaders:marcom'])
  end

  def nuid = '000000002'
  def mods(kind) = "/home/cerberus/web/spec/fixtures/files/#{kind}-mods.xml"

  def make_set(title = 'Civil Rights Materials')
    AtlasRb::Compilation.create(title, nuid: nuid)
  end

  describe 'access gates' do
    it 'redirects anonymous visitors to sign in for the index' do
      get '/sets'
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'rejects guest sessions with 403 (guests cannot curate sets)' do
      sign_in guest_user
      get '/sets'
      expect(response).to have_http_status(:forbidden)
    end

    it 'redirects anonymous picker requests to sign in' do
      get '/sets/picker', params: { work_id: 'abc1234' }
      expect(response).to redirect_to(new_user_session_path)
    end

    it '404s an unknown set id' do
      sign_in curator
      get '/sets/zzzzzzz'
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'CRUD' do
    before { sign_in curator }

    it 'lists my sets on the index' do
      set = make_set('Index Fixture Set')
      get '/sets'
      expect(response.body).to include('Index Fixture Set')
      expect(response.body).to include(set_path(set['id']))
    end

    it 'creates a set and lands on its page' do
      post '/sets', params: { set: { title: 'Brand New Set', description: 'For testing' } }
      expect(response).to have_http_status(:redirect)
      follow_redirect!
      expect(response.body).to include('Brand New Set')
    end

    it 're-renders the form with the Atlas message on a blank title' do
      post '/sets', params: { set: { title: '', description: '' } }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'updates title and description' do
      set = make_set('Before Rename')
      patch "/sets/#{set['id']}", params: { set: { title: 'After Rename', description: 'now described' } }
      follow_redirect!
      expect(response.body).to include('After Rename')
    end

    it 'destroys a set' do
      set = make_set('Doomed Set')
      delete "/sets/#{set['id']}"
      expect(response).to redirect_to(sets_path)
      get "/sets/#{set['id']}"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'recipe + show page' do
    let!(:community)  { public_container(AtlasRb::Community, nil) }
    let!(:collection) { public_container(AtlasRb::Collection, community.id) }
    let!(:work_one)   { public_work(collection.id) }
    let!(:work_two)   { public_work(collection.id) }
    let!(:lone_work)  { public_work(public_container(AtlasRb::Collection, community.id).id) }

    before { sign_in curator }

    it 'walks the whole flow: include, add, set aside, put back, remove' do
      set = make_set('Flow Set')

      post "/sets/#{set['id']}/collections", params: { collection_id: collection.id }
      post "/sets/#{set['id']}/works",       params: { work_id: lone_work.id }

      get "/sets/#{set['id']}"
      expect(response.body).to include('Flow Set')
        .and include('added directly')
        .and include('Set aside')

      # set one collection-sourced work aside: it leaves the rows, the chip
      # count diverges, and the teaching toast carries fresh counts + Undo
      post "/sets/#{set['id']}/aside",
           params: { work_id: work_one.id, title: 'Work One', chip: collection.id }
      follow_redirect!
      expect(response.body).to include('drs-toast')
        .and include('still in your set')
        .and include('1</span><span class="of"> of 2')

      # put it back: divergence gone
      delete "/sets/#{set['id']}/aside/#{work_one.id}"
      follow_redirect!
      expect(response.body).not_to include('of 2</span>')

      # remove the include; only the direct add remains
      delete "/sets/#{set['id']}/collections/#{collection.id}"
      follow_redirect!
      expect(response.body).to include('added directly')
      expect(response.body).not_to include('of 2')
    end

    it 'scopes a keyword search to the set contents' do
      set = make_set('Search Set')
      post "/sets/#{set['id']}/collections", params: { collection_id: collection.id }
      get "/sets/#{set['id']}", params: { q: 'zzz-no-such-term-zzz' }
      expect(response).to have_http_status(:ok)
    end

    describe 'the Add-to-set picker' do
      it 'marks included, set-aside, and addable states per set' do
        set = make_set('Picker Set')
        post "/sets/#{set['id']}/collections", params: { collection_id: collection.id }
        post "/sets/#{set['id']}/aside",       params: { work_id: work_one.id, title: 'Work One' }

        get '/sets/picker', params: { collection_id: collection.id }
        expect(response.body).to include('Already in this set')

        get '/sets/picker', params: { work_id: work_one.id }
        expect(response.body).to include('Set aside in this set')

        get '/sets/picker', params: { work_id: lone_work.id }
        expect(response.body).to include("/sets/#{set['id']}/works")
          .and include('New set')
      end

      it 'rejects a picker request with neither noid param' do
        get '/sets/picker'
        expect(response).to have_http_status(:bad_request)
      end

      it 'renders the affordance on work and collection show pages for a curator' do
        get "/works/#{lone_work.id}"
        expect(response.body).to include('Add to set')
        get "/collections/#{collection.id}"
        expect(response.body).to include('Add to set')
      end
    end

    it 'hides the picker affordance from anonymous visitors' do
      sign_out curator
      get "/works/#{lone_work.id}"
      expect(response.body).not_to include('Add to set')
    end

    it 'hides manage affordances from a non-owner with read access' do
      set = make_set('Owned Set')
      AtlasRb::Compilation.update(set['id'],
                                  permissions: { read: ['public'], edit: [], edit_users: [] },
                                  nuid:        nuid)
      sign_in other_user
      get "/sets/#{set['id']}"
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('Set aside')
      expect(response.body).not_to include(edit_set_path(set['id']))
    end
  end

  describe 'visibility' do
    it 'serves a public set to an anonymous visitor' do
      set = make_set('Public Set')
      AtlasRb::Compilation.update(set['id'],
                                  permissions: { read: ['public'], edit: [], edit_users: [] },
                                  nuid:        nuid)
      get "/sets/#{set['id']}"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Public Set')
    end

    it '403s an anonymous visitor on a private set' do
      set = make_set('Private Set')
      get "/sets/#{set['id']}"
      expect(response).to have_http_status(:forbidden)
    end
  end

  # --- helpers -------------------------------------------------------------

  def read_public = { 'permissions' => { 'read' => ['public'] } }

  def public_container(klass, parent_id)
    kind = klass.name.demodulize.downcase
    container = klass.create(parent_id, mods(kind), nuid: '000000004')
    klass.metadata(container.id, read_public, nuid: '000000004')
    container
  end

  def public_work(parent_id)
    work = AtlasRb::Work.create(parent_id, mods('work'), nuid: '000000004')
    AtlasRb::Work.complete(work.id, nuid: '000000004')
    AtlasRb::Work.metadata(work.id, read_public, nuid: '000000004')
    work
  end
end
