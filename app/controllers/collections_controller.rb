class CollectionsController < CatalogController
  include Blacklight::SearchHelper
  include Blacklight::TokenBasedUser
  include Blacklight::Configurable
  copy_blacklight_config_from(CatalogController)

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

  def member_search_builder
    @member_search_builder ||= CollectionMemberSearchBuilder.new(self)
  end

  def show
    @response, @document = fetch(params[:id])
    @response = repository.search(member_search_builder.with(params.merge(collection: params[:id])).query)
    @documents = @response.documents
  end

  private
    def collection_params
      params.require(:collection).permit(:title, :description)
    end
end
