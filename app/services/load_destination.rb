# frozen_string_literal: true

# Whether a load may stage into the chosen destination. The upload form's
# picker is only a convenience: the POST can name any NOID, so every loader
# checks it here before an archive is staged.
class LoadDestination < ApplicationService
  def initialize(loader:, parent_id:)
    @loader    = loader
    @parent_id = parent_id
  end

  # IPTC is boxed to the Collections its dropdown lists. XML and multipage take
  # any Collection. A blank destination is left to the XML preview: an
  # overwrite package names every Work it touches, and only a create row needs
  # one.
  def call
    return listed_for_iptc? if @loader.iptc?
    return @loader.xml? if @parent_id.blank?

    # find returns nil for a 404 (unknown NOID) and raises ResourceError for
    # any other non-2xx; either way the destination isn't a usable Collection.
    AtlasRb::Resource.find(@parent_id)&.klass == 'Collection'
  rescue Faraday::Error, JSON::ParserError, AtlasRb::ResourceError
    false
  end

  private

    # IptcDestinations reads an Atlas failure as an empty list, so an outage
    # refuses the load rather than trusting the NOID.
    def listed_for_iptc?
      IptcDestinations.call(root: @loader.root_collection).any? { |node| node['noid'] == @parent_id }
    end
end
