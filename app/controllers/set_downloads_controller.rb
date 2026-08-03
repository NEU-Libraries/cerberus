# frozen_string_literal: true

# Bulk download of a Set's content as a streamed ZIP.
#
# A dedicated controller (not an action on SetsController) because
# ActionController::Live streams *every* action in its controller — same
# reason DownloadsController is its own thing. Subclasses CatalogController so
# it inherits the GatedSearchService + search_service_context: the contents
# resolve through the identical gated search the Set show page uses, so a
# viewer only ever zips what they can discover.
#
# Discovery gating is NOT the whole of it, and reading it that way is how
# embargoed content reached anonymous archives: an embargoed Work is
# deliberately discoverable — public metadata, withheld content — so it clears
# the gated search and arrives at the packer like any other member. The
# per-file rule lives in SetZipPacker, which is handed the CALLER's bypass
# right rather than inheriting the set owner's reach.
#
# Auth mirrors SetsController#show: no authenticate_user!, no curator gate —
# a public Set is publicly downloadable; a private one 403s at
# Compilation.find (Atlas is the boundary). The heavy lifting is in
# SetZipPacker; this just resolves, guards empty, and opens the stream.
class SetDownloadsController < CatalogController
  include ProxyUnbuffered
  include ZipKit::RailsStreaming

  # A private Set the caller can't read → Atlas 403 → standard forbidden page;
  # unknown ids surface as JSON::ParserError via Authorizable's 404 path.
  rescue_from AtlasRb::ForbiddenError do
    render template: 'errors/forbidden', status: :forbidden
  end

  def show
    set = AtlasRb::Compilation.find(params[:id])
    raise ResourceNotFound if set.nil?

    resolver = SetResolver.new(compilation: set, search_service: search_service)

    if resolver.contents_count.zero?
      return redirect_to set_path(set['id']), alert: 'This set has no downloadable content.'
    end

    zip_kit_stream(filename: zip_filename(set)) { |zip| packer_for(resolver).pack(zip) }
  end

  private

    def packer_for(resolver)
      SetZipPacker.new(resolver: resolver, nuid: current_user&.nuid,
                       bypass_embargo: bypass_embargo?)
    end

    # The CALLER's right, never the set owner's — inheriting the owner's reach
    # is what put embargoed bytes into anonymous archives.
    def bypass_embargo?
      current_user.present? && current_user.can_bypass_embargo?
    end

    def zip_filename(set)
      slug = set['title'].to_s.parameterize.presence || 'set'
      "#{slug}-#{set['id']}.zip"
    end
end
