# frozen_string_literal: true

# Bulk metadata export of a Collection's member Works: a streamed ZIP carrying a
# re-ingestable manifest.xlsx (+ optional per-item MODS XML). The collection
# counterpart of {SetExportsController}; see it for the
# dedicated-controller / Live / gating rationale, and {MetadataExportPacker}
# for the bundle shape. Member resolution runs through the gated
# {CollectionContentsResolver} (CatalogController's SearchService), so a viewer
# only exports the Works they can discover.
class CollectionExportsController < CatalogController
  include ActionController::Live
  include ZipKit::RailsStreaming
  include LoaderGated

  rescue_from AtlasRb::ForbiddenError do
    render template: 'errors/forbidden', status: :forbidden
  end

  def show
    collection = AtlasRb::Collection.find(params[:id])
    raise ResourceNotFound if collection.nil?

    resolver = CollectionContentsResolver.new(valkyrie_id:    collection.valkyrie_id,
                                              search_service: search_service)

    if resolver.contents_count.zero?
      return redirect_to collection_path(collection.id), alert: 'This collection has no metadata to export.'
    end

    packer = MetadataExportPacker.new(docs: resolver, include_mods: include_mods?)
    zip_kit_stream(filename: export_filename(collection)) { |zip| packer.pack(zip) }
  end

  private

    # MODS bundled by default; `?mods=0` is the manifest-only path.
    def include_mods?
      params[:mods] != '0'
    end

    def export_filename(collection)
      slug = collection['title'].to_s.parameterize.presence || 'collection'
      "#{slug}-#{collection.id}-metadata.zip"
    end
end
