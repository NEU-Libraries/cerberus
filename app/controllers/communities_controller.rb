# frozen_string_literal: true

class CommunitiesController < CatalogController
  def show
    @community = AtlasRb::Community.find(params[:id])
    @response = find_many(AtlasRb::Community.children(params[:id]))
  end

  def new
    @community = OpenStruct.new
  end

  def edit
    # TODO: need to do admin check
    @community = AtlasRb::Community.find(params[:id])
  end

  def create
    permitted = params.require(:community).permit(:title, :description).to_h

    c = AtlasRb::Community.create(params[:parent_id])
    AtlasRb::Community.metadata(c['id'], permitted)
    redirect_to community_path(c['id'])
  end

  def update
    # allow for thumbnail
    file = params[:thumbnail]
    img = Vips::Image.new_from_file(file.tempfile.path.presence || file.path)
    # convert to jp2 and write to shared volume with iiif container
    uuid = Time.now.to_f.to_s.gsub!('.', '')
    img.jp2ksave("/home/cerberus/images/#{uuid}.jp2")
    permitted = params.require(:community).permit(:title, :description).to_h
    # write thumbnail URL to Atlas
    permitted[:thumbnail] = "http://#{request.host}:8182/iiif/3/#{uuid}.jp2"
    AtlasRb::Community.metadata(params[:id], permitted)
    redirect_to community_path(params[:id])
  end
end
