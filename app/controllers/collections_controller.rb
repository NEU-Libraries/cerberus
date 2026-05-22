# frozen_string_literal: true

class CollectionsController < CatalogController
  include Thumbable
  include Transformable

  before_action :authorize_edit!, only: [:edit]
  before_action :authorize_tombstone!, only: [:tombstone]

  def show
    @collection = AtlasRb::Collection.find(params[:id], nuid: Current.nuid)
    return render_gone(@collection) if @collection.tombstoned

    authorize_show!
    @response = find_children(@collection.valkyrie_id)
    @can_tombstone = current_ability.can?(:tombstone,
                                          solr_doc_from_permissions(@permissions, klass: 'Collection'))
    breadcrumbs(params[:id])
  end

  def tombstone
    AtlasRb::Collection.tombstone(params[:id], nuid: Current.nuid)
    redirect_to root_path, notice: 'Collection deleted.'
  end

  def new
    @collection = OpenStruct.new
  end

  def edit
    @collection = AtlasRb::Collection.find(params[:id], nuid: Current.nuid)
    form_preparation(@permissions)
  end

  def create
    permitted = params.expect(collection: [:title, :description]).to_h
    c = AtlasRb::Collection.create(params[:parent_id], nuid: Current.nuid)
    AtlasRb::Collection.metadata(c.id, permitted, nuid: Current.nuid)
    redirect_to collection_path(c.id)
  end

  def update
    AtlasRb::Collection.metadata(params[:id], collection_params, nuid: Current.nuid)
    redirect_to collection_path(params[:id])
  end

  private

    def collection_params
      resource_params(:collection)
    end
end
