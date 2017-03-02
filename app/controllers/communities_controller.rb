class CommunitiesController < CatalogController
  include Blacklight::Configurable
  include Blacklight::SearchHelper
  include Blacklight::TokenBasedUser

  copy_blacklight_config_from(CatalogController)

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

  def show
    # @document = solr_query("id:#{params[:id]}").first
    @response, @document = fetch(params[:id])
  end

  private
    def community_params
      params.require(:community).permit(:title, :description)
    end
end
