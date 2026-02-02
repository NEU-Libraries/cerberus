# frozen_string_literal: true

class CollectionsController < CatalogController
  include Thumbable

  def show
    @collection = AtlasRb::Collection.find(params[:id])
    @response = find_many(AtlasRb::Collection.children(params[:id]))
    breadcrumbs(params[:id])
  end

  def new
    @collection = OpenStruct.new
  end

  def edit
    @collection = AtlasRb::Collection.find(params[:id])
    @groups = current_user.groups.map { |value| [value, pretty_group(value)] }
    @permissions = AtlasRb::Resource.permissions(params[:id]).slice(
      'read', 'edit'
    ).flat_map do |key, values|
      permission = key == 'read' ? 'View' : 'Manage'
      values.map { |value| [value, pretty_group(value), permission] }
    end
  end

  def create
    permitted = params.require(:collection).permit(:title, :description).to_h
    c = AtlasRb::Collection.create(params[:parent_id])
    AtlasRb::Collection.metadata(c['id'], permitted)
    redirect_to collection_path(c['id'])
  end

  def update
    # TODO: need to do permissions check
    # permitted = params.require(:collection).permit(:title, :description).to_h
    # add_thumbnail(permitted)
    # AtlasRb::Collection.metadata(params[:id], permitted)
    # redirect_to collection_path(params[:id])
    puts "DGC INSPECT params[:groups]"
    puts params[:groups].inspect

    # @collection.permissions = params[:metadata]['permissions'] if params[:metadata]['permissions'].present?
  end
end
