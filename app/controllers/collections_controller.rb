# frozen_string_literal: true

class CollectionsController < CatalogController
  include Thumbable
  include Transformable
  include ShowScopedSearch
  include DepositorContext
  include CollectionBreadcrumbs
  include RecordsImpressions

  authorize_resource_writes!
  after_action :record_view_impression, only: :show

  # Scope the inherited Blacklight index to Collections only (see
  # CommunitiesController#search_service_context for the rationale and the
  # :index-only scoping). The :show page's find_children lists child Works, so
  # it must not be filtered to Collections.
  def search_service_context
    return super unless action_name == 'index'

    super.merge(resource_type_scope: 'Collection')
  end

  def show
    @collection = AtlasRb::Collection.find(params[:id])
    raise ResourceNotFound if @collection.nil?
    return render_gone(@collection) if @collection.tombstoned

    authorize_show!
    @response = find_children(@collection.valkyrie_id, params[:id])
    assign_show_abilities!(klass: 'Collection')
    collection_breadcrumbs(params[:id])
  end

  def tombstone
    perform_tombstone!(AtlasRb::Collection.tombstone(params[:id]), type: 'Collection')
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

  # The personal-root-aware breadcrumb trail (collection_breadcrumbs + helpers)
  # lives in CollectionBreadcrumbs, shared with XmlController's raw-XML editor.
end
