# frozen_string_literal: true

class CommunitiesController < CatalogController
  def show
    @community = Community.find(params[:id])
    @response = find_many(@community.filtered_children)
  end
end
