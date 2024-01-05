# frozen_string_literal: true

class CommunitiesController < CatalogController
  def show
    # @community = Community.find(params[:id])
    # @response = find_many(@community.filtered_children)

    @community = AtlasRb::Community.find(params[:id])
    @response = find_many(AtlasRb::Community.children(params[:id]))
  end

  def new
    # @resource = CommunityChangeSet.new(Community.new)
  end

  def edit
    # TODO: need to do admin check
    # @resource = CommunityChangeSet.new(Community.find(params[:id]).decorate)
    @resource = Forms::Community.new(OpenStruct.new(AtlasRb::Community.find(params[:id])))
  end

  def create
    # puts params.inspect
    # c = Community.new
    # change_set = ProjectChangeSet.new(Project.new(user_registry_id: user_registry.id))
    # if change_set.validate(params[:project])
    #   change_set.sync
    #   @project = metadata_adapter.persister.save(resource: change_set.resource)
    # end
  end
end
