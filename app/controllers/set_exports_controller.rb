# frozen_string_literal: true

# Bulk metadata export of a Set: a streamed ZIP carrying a re-ingestable
# manifest.xlsx (+ optional per-item MODS XML). See {MetadataExportPacker}.
#
# A dedicated controller (not an action on SetsController) for the same reason
# as SetDownloadsController: ActionController::Live streams *every* action in
# its controller. Subclasses CatalogController to inherit the gated
# SearchService + search_service_context, so the contents resolve through the
# identical gated search the Set show page uses — a viewer only ever exports
# what they can discover.
#
# Unlike SetDownloadsController, export is a librarian/migration tool, so it is
# gated to the loader tier ({LoaderGated}), even for a public Set. A private Set
# the caller cannot read still 403s at Compilation.find (Atlas is the boundary).
class SetExportsController < CatalogController
  include ActionController::Live
  include ZipKit::RailsStreaming
  include LoaderGated

  rescue_from AtlasRb::ForbiddenError do
    render template: 'errors/forbidden', status: :forbidden
  end

  def show
    set = AtlasRb::Compilation.find(params[:id])
    raise ResourceNotFound if set.nil?

    resolver = SetResolver.new(compilation: set, search_service: search_service)

    if resolver.contents_count.zero?
      return redirect_to set_path(set['id']), alert: 'This set has no metadata to export.'
    end

    packer = MetadataExportPacker.new(docs: resolver, include_mods: include_mods?)
    zip_kit_stream(filename: export_filename(set)) { |zip| packer.pack(zip) }
  end

  private

    # MODS bundled by default; `?mods=0` is the manifest-only path.
    def include_mods?
      params[:mods] != '0'
    end

    def export_filename(set)
      slug = set['title'].to_s.parameterize.presence || 'set'
      "#{slug}-#{set['id']}-metadata.zip"
    end
end
