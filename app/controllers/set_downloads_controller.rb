# frozen_string_literal: true

# Bulk download of a Set's content as a streamed ZIP. A dedicated controller,
# never an action on SetsController, because ActionController::Live streams
# *every* action in its controller; subclassing CatalogController is what
# supplies the gated search service. See docs/sets.md.
class SetDownloadsController < CatalogController
  include ProxyUnbuffered
  include ZipKit::RailsStreaming

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
      SetZipPacker.new(resolver: resolver, nuid: effective_user&.nuid,
                       ability: current_ability, bypass_embargo: bypass_embargo?)
    end

    # The CALLER's right, never the set owner's — inheriting the owner's reach
    # is what put embargoed bytes into anonymous archives. `effective_user`, not
    # `current_user`, so a View-as session zips what the target can reach.
    def bypass_embargo?
      effective_user.present? && effective_user.can_bypass_embargo?
    end

    def zip_filename(set)
      slug = set['title'].to_s.parameterize.presence || 'set'
      "#{slug}-#{set['id']}.zip"
    end
end
