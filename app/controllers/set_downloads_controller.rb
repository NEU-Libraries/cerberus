# frozen_string_literal: true

# Bulk download of a Set's content as a streamed ZIP.
#
# A dedicated controller (not an action on SetsController) because
# ActionController::Live streams *every* action in its controller — same
# reason DownloadsController is its own thing. Subclasses CatalogController so
# it inherits the GatedSearchService + search_service_context: the contents
# resolve through the identical gated search the Set show page uses, so a
# viewer only ever zips what they can discover (per-member gating is free).
#
# Auth mirrors SetsController#show: no authenticate_user!, no curator gate —
# a public Set is publicly downloadable; a private one 403s at
# Compilation.find (Atlas is the boundary). The heavy lifting is in
# SetZipPacker; this just resolves, guards empty, and opens the stream.
class SetDownloadsController < CatalogController
  include ActionController::Live
  include ZipKit::RailsStreaming

  # A private Set the caller can't read → Atlas 403 → standard forbidden page;
  # unknown ids surface as JSON::ParserError via Authorizable's 404 path.
  rescue_from AtlasRb::ForbiddenError do
    render template: 'errors/forbidden', status: :forbidden
  end

  def show
    set = AtlasRb::Compilation.find(params[:id])
    resolver = SetResolver.new(compilation: set, search_service: search_service)

    if resolver.contents_count.zero?
      return redirect_to set_path(set['id']), alert: 'This set has no downloadable content.'
    end

    packer = SetZipPacker.new(resolver: resolver, nuid: current_user&.nuid)
    zip_kit_stream(filename: zip_filename(set)) { |zip| packer.pack(zip) }
  end

  private

    def zip_filename(set)
      slug = set['title'].to_s.parameterize.presence || 'set'
      "#{slug}-#{set['id']}.zip"
    end
end
