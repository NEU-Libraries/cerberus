# frozen_string_literal: true

class CollectionsController < CatalogController
  include Thumbable
  include Transformable

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
    form_preparation(AtlasRb::Resource.permissions(params[:id]))
  end

  def create
    permitted = params.expect(collection: [:title, :description]).to_h
    c = AtlasRb::Collection.create(params[:parent_id])
    AtlasRb::Collection.metadata(c['id'], permitted)
    redirect_to collection_path(c['id'])
  end

  def update
    # TODO: need to do user permissions check
    AtlasRb::Collection.metadata(params[:id], collection_params)
    redirect_to collection_path(params[:id])
  end

  private

    def form_preparation(raw_permissions)
      @groups = pretty_user_permissions(current_user.groups)
      @public = raw_permissions['read']&.include?('public')
      @embargo = begin
        Date.parse(raw_permissions['embargo'])&.to_s
      rescue Date::Error
        ''
      end
      @permissions = pretty_resource_permissions(raw_permissions)
    end

    def collection_params
      permitted = params.expect(collection:
      [
        :title,
        :description,
        :embargo,
        permissions: [:group_id, :ability]
      ]).to_h

      transform_permissions(permitted)
      mass_permissions(permitted)

      add_thumbnail(permitted)

      permitted
    end

    def transform_permissions(permitted)
      # transform ugly form values into Atlas ready versions
      return unless params[:collection][:permissions]

      permitted[:permissions] = form_group_permissions(params[:collection][:permissions])

      if params[:collection][:permissions][:embargo].present?
        permitted[:permissions][:embargo] = params[:collection][:permissions][:embargo]
      end
    end

    def mass_permissions(permitted)
      return unless params[:mass]

      if params[:mass] == 'public'
        permitted[:permissions][:read] |= ['public']
      elsif permitted[:permissions][:read]
        permitted[:permissions][:read].delete('public')
      end
    end
end
