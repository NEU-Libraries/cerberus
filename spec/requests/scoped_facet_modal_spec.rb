# frozen_string_literal: true

require 'rails_helper'

# The facet "more" modal on a container show page, end to end over the real
# test Atlas.
#
# Blacklight generates the sidebar's link for the `facet` action on the current
# controller and passes the facet key as :id. On these pages :id already names
# the container, so without the scoped route the key overwrites it, url_for
# raises inside the view, and the whole page 500s. Several examples here assert
# a plain 200 on the show page for exactly that reason: the regression is not a
# broken link, it is a dead page.
RSpec.describe 'Scoped facet modal', type: :request do
  include Devise::Test::IntegrationHelpers

  # The Work fixture carries seven topics against a default_facet_limit of 5, so
  # one deposit is enough to overflow the Topic facet and render the link.
  IN_SCOPE_TOPIC = 'Textile industry'
  OUT_OF_SCOPE_TOPIC = 'Shipbuilding'

  def nuid = '000000004'
  # Rails.root, not the container's main-checkout path: these fixtures are new,
  # so in a worktree run they exist only under the worktree.
  def mods(kind) = Rails.root.join("spec/fixtures/files/#{kind}-mods.xml").to_s
  def read_public = { 'permissions' => { 'read' => ['public'] } }
  def read_staff  = { 'permissions' => { 'read' => ['northeastern:drs:repository:staff'] } }

  def public_container(klass, parent_id, fixture = nil)
    kind = fixture || klass.name.demodulize.downcase
    container = klass.create(parent_id, mods(kind), nuid: nuid)
    klass.metadata(container.id, read_public, nuid: nuid)
    container
  end

  def public_work(parent_id, fixture)
    work = AtlasRb::Work.create(parent_id, mods(fixture), nuid: nuid)
    AtlasRb::Work.complete(work.id, nuid: nuid)
    AtlasRb::Work.metadata(work.id, read_public, nuid: nuid)
    work
  end

  # One tree, deposited once: the anchor collection holds the many-topic Work,
  # and a sibling collection holds a Work whose single topic must never appear
  # in the anchor's modal.
  before(:context) do
    @community  = public_container(AtlasRb::Community, nil)
    @collection = public_container(AtlasRb::Collection, @community.id)
    @sibling    = public_container(AtlasRb::Collection, @community.id)
    @work       = public_work(@collection.id, 'work-many-topics')
    @neighbour  = public_work(@sibling.id, 'work-one-topic')
    # Containers of their own carrying the many-topic MODS, so the :index
    # listings below — which facet over containers, not Works — overflow the
    # Topic facet too and would render a "more" link if one were offered.
    @topical_collection = public_container(AtlasRb::Collection, @community.id, 'work-many-topics')
    @topical_community  = public_container(AtlasRb::Community, nil, 'work-many-topics')
  end

  let(:community)  { @community }
  let(:collection) { @collection }
  let(:work)       { @work }

  let(:curator) do
    User.new(email: 'dps@example.com', password: 'password',
             nuid: '000000002', role: 'privileged',
             groups: ['northeastern:drs:repository:staff'])
  end

  describe 'the sidebar link on a collection' do
    it 'renders the show page and points "more" at the scoped facet route' do
      get collection_path(collection.id)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(facet_collection_path(id: collection.id, facet_field: 'subject_ssim'))
    end

    it 'renders the show page for a gallery view too' do
      get collection_path(collection.id, view: 'gallery')

      expect(response).to have_http_status(:ok)
    end

    # The keyword branch swaps the direct-member fq for the subtree one, which
    # is the other half of child_membership_filters.
    it 'renders the show page with a keyword query' do
      get collection_path(collection.id, q: 'Merrimack')

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET the scoped facet modal' do
    it 'lists the values held by this collection' do
      get facet_collection_path(id: collection.id, facet_field: 'subject_ssim')

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(IN_SCOPE_TOPIC)
    end

    # The point of the scope. An unscoped modal would count the whole index and
    # surface the sibling collection's value here.
    it 'omits values held only outside this collection' do
      get facet_collection_path(id: collection.id, facet_field: 'subject_ssim')

      expect(response.body).not_to include(OUT_OF_SCOPE_TOPIC)
    end

    it 'counts the whole community from the community modal' do
      get facet_community_path(id: community.id, facet_field: 'subject_ssim')

      expect(response).to have_http_status(:ok)
    end

    it '404s a facet the catalog does not configure' do
      get facet_collection_path(id: collection.id, facet_field: 'not_a_facet_ssim')

      expect(response).to have_http_status(:not_found)
    end

    it '404s an unknown collection' do
      get facet_collection_path(id: 'zzzzzzzzz', facet_field: 'subject_ssim')

      expect(response).to have_http_status(:not_found)
    end

    # Blacklight's suggest JS keeps only the first path segment of this context
    # and appends /facet_suggest/<key>. The container therefore has to be in the
    # query string to survive, which is what the dedicated route buys.
    it 'points the suggest box at a context whose container is a query param' do
      get facet_collection_path(id: collection.id, facet_field: 'subject_ssim')

      expect(response.body).to include('facet-suggest')
      expect(response.body).to include(
        CGI.escapeHTML(collection_facet_suggest_path(facet_field: 'subject_ssim', id: collection.id))
      )
    end
  end

  # The type-ahead behind the modal's filter box. It is a second read surface
  # over the same counts, so it repeats the scope and gating assertions rather
  # than trusting the modal's.
  describe 'GET the scoped facet suggest' do
    def suggest(id:, facet_field: 'subject_ssim', **params)
      get collection_facet_suggest_path(facet_field: facet_field, id: id, **params)
    end

    it 'lists the values held by this collection' do
      suggest(id: collection.id)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(IN_SCOPE_TOPIC)
    end

    it 'omits values held only outside this collection' do
      suggest(id: collection.id)

      expect(response.body).not_to include(OUT_OF_SCOPE_TOPIC)
    end

    it 'narrows the list to the typed fragment' do
      suggest(id: collection.id, query_fragment: IN_SCOPE_TOPIC[0, 6])

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(IN_SCOPE_TOPIC)
    end

    it 'drops values the fragment does not match' do
      suggest(id: collection.id, query_fragment: 'zzzznotatopic')

      expect(response.body).not_to include(IN_SCOPE_TOPIC)
    end

    # The fragment is a filter, not a requirement: the box is empty until
    # someone types, and that request must still count everything.
    it 'counts everything when no fragment is given' do
      suggest(id: collection.id, query_fragment: '')

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(IN_SCOPE_TOPIC)
    end

    it '404s a facet the catalog does not configure' do
      suggest(id: collection.id, facet_field: 'not_a_facet_ssim')

      expect(response).to have_http_status(:not_found)
    end

    it '404s an unknown collection' do
      suggest(id: 'zzzzzzzzz')

      expect(response).to have_http_status(:not_found)
    end

    # This route's container is a query param, so unlike the modal's the router
    # cannot vouch for it being there at all.
    it '404s when no container is given' do
      get collection_facet_suggest_path(facet_field: 'subject_ssim')

      expect(response).to have_http_status(:not_found)
    end
  end

  # A private container's contents are not countable by someone who cannot read
  # the container. The modal is a read surface like any other.
  describe 'gating' do
    # Written explicitly, because a minted child inherits its parent's ACL — and
    # the parent community here is public, so an unwritten collection is born
    # readable and would prove nothing.
    let(:private_collection) do
      c = AtlasRb::Collection.create(community.id, mods('collection'), nuid: nuid)
      AtlasRb::Collection.metadata(c.id, read_staff, nuid: nuid)
      c
    end
    let!(:private_work) do
      w = AtlasRb::Work.create(private_collection.id, mods('work-many-topics'), nuid: nuid)
      AtlasRb::Work.complete(w.id, nuid: nuid)
      w
    end

    # The modal must be no more permissive than the page it hangs off. Asserted
    # as parity with the show page rather than as a literal status, so the pair
    # stays coupled wherever the refusal contract lands.
    it 'refuses the modal exactly as the show page refuses' do
      get collection_path(private_collection.id)
      show_status = response.status

      get facet_collection_path(id: private_collection.id, facet_field: 'subject_ssim')

      expect(response.status).to eq(show_status)
      expect(response).not_to have_http_status(:ok)
    end

    it 'serves it to a caller who can read the collection' do
      sign_in curator
      get facet_collection_path(id: private_collection.id, facet_field: 'subject_ssim')

      expect(response).to have_http_status(:ok)
    end

    # The suggest route reaches the same counts by a different path, so it needs
    # its own gate assertion — a modal that refuses is worth little if the box
    # inside it answers.
    it 'refuses the suggest exactly as the show page refuses' do
      get collection_path(private_collection.id)
      show_status = response.status

      get collection_facet_suggest_path(facet_field: 'subject_ssim', id: private_collection.id,
                                        query_fragment: 'a')

      expect(response.status).to eq(show_status)
      expect(response).not_to have_http_status(:ok)
    end

    it 'serves the suggest to a caller who can read the collection' do
      sign_in curator
      get collection_facet_suggest_path(facet_field: 'subject_ssim', id: private_collection.id)

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'a Set show page' do
    let(:set) { AtlasRb::Compilation.create('Facet Modal Set', nuid: '000000002') }

    before { sign_in curator }

    it 'renders, and serves the modal over the resolved contents' do
      post "/sets/#{set['id']}/collections", params: { collection_id: collection.id }

      get "/sets/#{set['id']}"
      expect(response).to have_http_status(:ok)

      get facet_set_path(id: set['id'], facet_field: 'subject_ssim')
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(IN_SCOPE_TOPIC)
    end

    # An empty recipe denotes nothing, so the modal must count nothing rather
    # than falling back to the whole index.
    it 'renders an empty modal for a set with no recipe' do
      get facet_set_path(id: set['id'], facet_field: 'subject_ssim')

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(IN_SCOPE_TOPIC)
    end
  end

  # The same controllers also serve an unscoped :index. There is no container
  # there, so there is no modal — and a link built anyway would put a nil in the
  # :id segment and take the listing down.
  describe 'the unscoped index listings' do
    it 'renders /collections with no "more" link' do
      get collections_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('more_facets')
    end

    it 'renders /communities with no "more" link' do
      get communities_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('more_facets')
    end
  end

  # These two embed the same sidebar and own no facet route, so the link has to
  # be off rather than pointing somewhere that raises.
  describe 'surfaces without a facet modal' do
    it 'renders the Faculty & Staff browse with no "more" link' do
      get people_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('more_facets')
    end

    it 'renders a Featured Content category with no "more" link' do
      get genre_path(category: 'Research Publications')

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('more_facets')
    end
  end
end
