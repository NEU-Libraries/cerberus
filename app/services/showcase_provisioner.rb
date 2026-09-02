# frozen_string_literal: true

# Provisions a community's genre showcase Collections, one featured Collection
# per scholarly genre. See docs/discovery.md.
class ShowcaseProvisioner < ApplicationService
  include AtlasWrite

  def initialize(community_id:)
    @community_id = community_id
    super()
  end

  def call
    FeaturedContent.genre_labels.each_with_object({}) do |label, map|
      showcase = provision(label)
      map[label] = showcase if showcase
    end
  end

  private

    # Record the showcase as unowned. Falling through to the acting principal
    # would make whoever created the Community the depositor of every showcase
    # under it, and depositor implies edit.
    # Rescue AtlasRb::Error alongside the transport faults: the container-create
    # gate's 403 reaches this path as an exception, and letting it escape aborts
    # the whole provisioning run and the community create that triggered it.
    def provision(label)
      showcase = AtlasRb::Collection.create(@community_id,
                                            featured:  true,
                                            depositor: Permissions::UNOWNED_NUID)
      set_title(showcase.id, label)
      showcase
    rescue AtlasRb::Error, Faraday::Error, JSON::ParserError => e
      Rails.logger.warn("[showcase provisioning] #{label} under #{@community_id} failed: " \
                        "#{e.class}: #{e.message}")
      nil
    end

    def set_title(id, label)
      xml = AtlasRb::Collection.mods(id, 'xml')
      merged = Metadata::MODSMerge.call(xml: xml, title: label,
                                        abstract: "Featured #{label.downcase} for this community.")
      return if Metadata::MODSMerge.unchanged?(xml, merged)

      AtlasRb::Collection.update(id, write_tmp_xml(merged))
    end
end
