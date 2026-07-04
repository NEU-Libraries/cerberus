# frozen_string_literal: true

# Provisions a community's genre "showcase" Collections — the featured containers
# the deposit fork publishes into, one per scholarly genre. Shared by
# CommunitiesController#create (every new community is provisioned on creation)
# and the dev/staging reset seed. Each showcase is a featured Collection titled
# after its genre, via the same structure-safe MODS merge the descriptive forms
# use. A per-showcase failure is logged and skipped so one bad create can't abort
# the rest — the community already exists by this point, and a missing showcase
# can be re-created later. The acting principal comes from the ambient
# Current.nuid (set by the controller, or the reset seed's Current.set block).
class ShowcaseProvisioner < ApplicationService
  def initialize(community_id:)
    @community_id = community_id
    super()
  end

  # @return [Hash{String => AtlasRb::Mash}] created showcases keyed by genre label.
  def call
    FeaturedContent.genre_labels.each_with_object({}) do |label, map|
      showcase = provision(label)
      map[label] = showcase if showcase
    end
  end

  private

    def provision(label)
      showcase = AtlasRb::Collection.create(@community_id, featured: true)
      set_title(showcase.id, label)
      showcase
    rescue Faraday::Error, JSON::ParserError => e
      Rails.logger.warn("[showcase provisioning] #{label} under #{@community_id} failed: #{e.message}")
      nil
    end

    # Title the showcase after its genre via the structure-safe MODS merge (parse
    # the freshly-minted MODS, merge the title/abstract in, write the raw XML
    # back) — the same path Transformable#save_descriptive! uses.
    def set_title(id, label)
      xml = AtlasRb::Collection.mods(id, 'xml')
      merged = Metadata::MODSMerge.call(xml: xml, title: label,
                                        abstract: "Featured #{label.downcase} for this community.")
      return if Metadata::MODSMerge.unchanged?(xml, merged)

      AtlasRb::Collection.update(id, write_tmp_xml(merged))
    end

    def write_tmp_xml(xml)
      path = Rails.root.join('tmp', "#{SecureRandom.uuid}.xml").to_s
      File.write(path, xml)
      path
    end
end
