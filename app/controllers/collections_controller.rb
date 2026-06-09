# frozen_string_literal: true

class CollectionsController < CatalogController
  include Thumbable
  include Transformable
  include ShowScopedSearch

  before_action :authorize_edit!, only: [:edit]
  before_action :authorize_tombstone!, only: [:tombstone]

  def show
    @collection = AtlasRb::Collection.find(params[:id])
    return render_gone(@collection) if @collection.tombstoned

    authorize_show!
    @response = find_children(@collection.valkyrie_id, params[:id])
    @can_tombstone = current_ability.can?(:tombstone,
                                          solr_doc_from_permissions(@permissions, klass: 'Collection'))
    breadcrumbs(params[:id])
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
    breadcrumbs(params[:id], editing: true)
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
end
