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

  private

    # A personal workspace collection — one under the *viewer's own* Person
    # personal root — is trailed through "My DRS" (the owner's personal home)
    # rather than the structural "People / Personal Root" prefix, whose root
    # container isn't owner-navigable (it 403s). Everyone else, and every
    # non-workspace collection, gets the plain structural trail (sharing the one
    # AtlasRb::Resource.find via the result: hand-off).
    def collection_breadcrumbs(id)
      result = AtlasRb::Resource.find(id)
      root = deposit_person&.[]('personal_root_id').presence
      parent_noid = Array(result.resource.ancestor_chain).last&.dig('noid')

      if root && parent_noid == root
        breadcrumb('My DRS', my_drs_path)
        add_breadcrumb_for(result.resource.id, result.klass, result.resource.title)
      else
        breadcrumbs(id, result: result)
      end
    end
end
