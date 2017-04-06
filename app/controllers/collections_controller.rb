class CollectionsController < CatalogController
  include Blacklight::SearchHelper
  include Blacklight::TokenBasedUser
  include Blacklight::Configurable
  copy_blacklight_config_from(CatalogController)
  self.blacklight_config.facet_fields = blacklight_config.facet_fields

  attr_reader :item

  def new
    @set = Collection.new
  end

  def create
    if Collection.new(collection_params).save!
      flash[:notice] = "Collection successfully created."
      redirect_to root_path
    else
      flash.now.error = "Error occured creating collection."
    end
  end

  def show
    # @document = solr_query("id:#{params[:id]}").first
    @response, @document = fetch(params[:id])
    query = SearchBuilder.new([:add_paging_to_solr, :add_sorting_to_solr, :limit_to_collection_children], self).with(item_id: params[:id])
    @response = repository.search(query)
    @documents = @response.documents
    # @response, @documents = search_results(query) #don't think this is actually working?
  end

  private
    def collection_params
      params.require(:collection).permit(:title, :description)
    end
end
