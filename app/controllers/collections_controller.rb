# frozen_string_literal: true

class CollectionsController < CatalogController
  include Thumbable
  include Transformable
  include ShowScopedSearch
  include DepositorContext

  before_action :authorize_edit!, only: [:edit]
  before_action :authorize_tombstone!, only: [:tombstone]

  def show
    @collection = AtlasRb::Collection.find(params[:id])
    return render_gone(@collection) if @collection.tombstoned

    authorize_show!
    @response = find_children(@collection.valkyrie_id, params[:id])
    @can_tombstone = current_ability.can?(:tombstone,
                                          solr_doc_from_permissions(@permissions, klass: 'Collection'))
    collection_breadcrumbs(params[:id])
  end

  def tombstone
    AtlasRb::Collection.tombstone(params[:id])
    redirect_to root_path, notice: 'Collection deleted.'
  end

  def new
    @collection = OpenStruct.new
  end

  def edit
    @collection = AtlasRb::Collection.find(params[:id])
    form_preparation(@permissions)
    load_descriptive!('Collection')
    collection_breadcrumbs(params[:id], editing: true)
  end

  def create
    permitted = params.expect(collection: [:title, :description]).to_h
    c = AtlasRb::Collection.create(params[:parent_id])
    save_descriptive!('Collection', c.id, title: permitted['title'], description: permitted['description'])
    redirect_to collection_path(c.id)
  end

  def update
    handle_metadata_update(klass: 'Collection', resource_key: :collection, keywords: false)
  end

  private

    # A personal workspace collection (one under a Person's personal root) is
    # trailed away from the structural "People / Personal Root" prefix:
    #   * the owner sees "My DRS / <collection>" — their personal home;
    #   * everyone else (incl. logged-out) sees "People / <Person> / <collection>"
    #     — the public, person-rooted trail.
    # Any other collection gets the plain structural trail (sharing the one
    # AtlasRb::Resource.find via the result: hand-off). Shared by show and edit so
    # the edit page keeps the same personal-root prefix instead of falling back to
    # the structural "People / Personal Root" trail; +editing+ swaps in the edit
    # tail (collection as link + "Edit Collection" current crumb).
    def collection_breadcrumbs(id, editing: false)
      result = AtlasRb::Resource.find(id)
      parent_noid = Array(result.resource.ancestor_chain).last&.dig('noid')

      if owner_workspace?(parent_noid)
        breadcrumb('My DRS', my_drs_path)
        workspace_collection_tail(result, editing: editing)
      elsif (owner = personal_root_owner(parent_noid))
        breadcrumb('People', people_path)
        breadcrumb(owner['display_name'], person_path(owner['id']))
        workspace_collection_tail(result, editing: editing)
      else
        breadcrumbs(id, editing: editing, result: result)
      end
    end

    # The viewer is looking at a collection in their own personal-root workspace.
    def owner_workspace?(parent_noid)
      parent_noid.present? && parent_noid == deposit_person&.[]('personal_root_id')
    end

    # The trail tail after the personal-root prefix: on a show page the collection
    # is the you-are-here crumb; on an edit page it becomes a link back to the show
    # page followed by the "Edit Collection" current crumb (shared edit_breadcrumb_tail).
    def workspace_collection_tail(result, editing:)
      if editing
        edit_breadcrumb_tail(result.resource, result.klass)
      else
        add_breadcrumb_for(result.resource.id, result.klass, result.resource.title)
      end
    end

    # The Person who owns +parent_noid+ when it's a personal root (flagged
    # personal_root_bsi), else nil. The owning Person is resolved from the root's
    # depositor (Atlas mints the root with depositor = the person's NUID — more
    # reliable than the item's own depositor, which a proxy/seed may set to
    # someone else). A lookup failure degrades to nil → structural trail.
    def personal_root_owner(parent_noid)
      return nil if parent_noid.blank?

      root = collection_doc(parent_noid)
      return nil unless root&.personal_root?

      AtlasRb::Person.resolve([root['depositor_ssi']]).first
    rescue Faraday::Error, JSON::ParserError
      nil
    end

    # The Solr document for a Collection addressed by NOID (carries
    # personal_root_bsi + depositor_ssi), or nil.
    def collection_doc(noid)
      Blacklight.default_index.search(
        q: '*:*', rows: 1,
        fq: ['internal_resource_tesim:Collection', "alternate_ids_tesim:#{noid.to_s.gsub(/["\\:]/, '')}"]
      ).documents.first
    end
end
