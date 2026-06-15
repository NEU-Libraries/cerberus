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

    it 'mounts a lazy works-count frame per index row' do
      set = make_set('Counted Set')
      get '/sets'
      expect(response.body).to include(works_count_set_path(set['id']))
    end

    it 'creates a set and lands on its page' do
      post '/sets', params: { set: { title: 'Brand New Set', description: 'For testing' } }
      expect(response).to have_http_status(:redirect)
      follow_redirect!
      expect(response.body).to include('Brand New Set')
    end

    it 're-renders the form with the Atlas message on a blank title' do
      post '/sets', params: { set: { title: '', description: '' } }
      expect(response).to have_http_status(:unprocessable_content)
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
      end

      it 'filters rows by title and reports empty matches' do
        make_set('Findable Set')
        make_set('Other Curation')

        get '/sets/picker', params: { work_id: lone_work.id, q: 'findable' }
        expect(response.body).to include('Findable Set')
        expect(response.body).not_to include('Other Curation')

        get '/sets/picker', params: { work_id: lone_work.id, q: 'zzz-nope' }
        expect(response.body).to include('No sets match')
      end

      it 'paginates past one page of sets' do
        12.times { |i| make_set(format('Bulk Set %02d', i)) }
        get '/sets/picker', params: { work_id: lone_work.id }
        expect(response.body).to match(/1 of \d+/)
        get '/sets/picker', params: { work_id: lone_work.id, page: 2 }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('picker-row')
      end

      it 'rejects a picker request with neither noid param' do
        get '/sets/picker'
        expect(response).to have_http_status(:bad_request)
      end

      it 'mounts the row icon and work-kind modal in a collection contents listing' do
        get "/collections/#{collection.id}"
        expect(response.body).to include('Add to Set')
          .and include("add-to-set-#{work_one.id}")
          .and include('Filter your sets by title')
          .and include('New set')
      end

      it 'mounts the collection-kind modal with the live-subtree hint on community rows' do
        get "/communities/#{community.id}"
        expect(response.body).to include("add-to-set-#{collection.id}")
          .and include('stays current as the collection changes')
      end

      it 'mounts the row affordance on gallery-view cards too' do
        get "/collections/#{collection.id}", params: { view: 'gallery' }
        expect(response.body).to include('Add to Set')
          .and include("add-to-set-#{work_one.id}")
      end
    end

    describe 'the works-count tally' do
      def tally_text = response.body.gsub(/<[^>]+>/, ' ').squish

      it 'resolves the recipe to a gated count, honoring set-asides' do
        set = make_set('Tally Set')
        post "/sets/#{set['id']}/collections", params: { collection_id: collection.id }
        get "/sets/#{set['id']}/works_count"
        expect(tally_text).to eq('2 Works')

        post "/sets/#{set['id']}/aside", params: { work_id: work_one.id }
        get "/sets/#{set['id']}/works_count"
        expect(tally_text).to eq('1 Work')
      end

      it 'reports an empty recipe as zero' do
        set = make_set('Empty Tally Set')
        get "/sets/#{set['id']}/works_count"
        expect(tally_text).to eq('0 Works')
      end
    end

    it 'hides the row affordance from anonymous visitors' do
      sign_out curator
      get "/collections/#{collection.id}"
      expect(response.body).not_to include('add-to-set-')
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

  describe 'navbar user menu' do
    # The name block (and so the menu) only renders for users with a
    # parseable name — mirror that here, unlike the other fixtures.
    def named_user(role:, nuid:)
      User.new(email: "#{role}@example.com", password: 'password', name: 'Dee Ps',
               nuid: nuid, role: role, groups: ['northeastern:drs:repository:staff'])
    end

    it 'puts My Sets behind the split-button caret for a curator' do
      sign_in named_user(role: 'privileged', nuid: '000000002')
      get '/sets'
      expect(response.body).to include('dropdown-toggle-split')
        .and include('My Sets')
    end

    it 'adds Admin to the menu for admins' do
      sign_in named_user(role: 'admin', nuid: '000000004')
      get '/sets'
      expect(response.body).to include('dropdown-toggle-split')
      expect(response.body).to include(admin_root_path)
    end

    it 'keeps the plain name link for guests' do
      sign_in User.new(email: 'guest@example.com', password: 'password', name: 'Gee Uest',
                       nuid: '000000001', role: 'guest', groups: [])
      get '/'
      expect(response.body).not_to include('dropdown-toggle-split')
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
