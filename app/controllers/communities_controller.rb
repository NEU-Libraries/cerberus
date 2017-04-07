class CommunitiesController < CatalogController
  include Blacklight::Configurable
  include Blacklight::SearchHelper
  include Blacklight::TokenBasedUser

  copy_blacklight_config_from(CatalogController)

  # introduce custom logic for choosing which action the search form should use
  def search_action_url options = {}
    search_catalog_url(options.except(:controller, :action))
  end

  def new
    @set = Community.new
  end

  def create
    if Community.new(community_params).save!
      flash[:notice] = "Community successfully created."
      redirect_to root_path
    else
      flash.now.error = "Error occured creating community."
    end
  end

  def member_search_builder
    @member_search_builder ||= CommunityMemberSearchBuilder.new(self)
  end

  def show
    @response, @document = fetch(params[:id])
    @response = repository.search(member_search_builder.with(params.merge(community: params[:id])).query)
    @documents = @response.documents
  end


  private
    def community_params
      params.require(:community).permit(:title, :description)
    end
end
