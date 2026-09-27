# frozen_string_literal: true

# The IPTC loader's destination picker: the live Collections directly under the
# loader's root, in Atlas's children order. XML and multipage loaders search all
# Collections instead, so this is IPTC-only.
class IptcDestinations < ApplicationService
  def initialize(root:)
    @root = root
  end

  # Atlas's children endpoint returns ids only; one batched find_many resolves
  # them. find_many is unordered and drops unresolvable ids (or returns nil on a
  # 404), so index by noid and re-impose the children order.
  #
  # A failure reads as "no destinations" rather than a 500: the form then
  # disables Upload, which is the honest state when Atlas can't be read.
  def call
    ids = AtlasRb::Collection.children(@root)
    return [] if ids.blank?

    by_noid = Array(AtlasRb::Resource.find_many(ids)).index_by { |node| node['noid'] }
    ids.filter_map { |id| by_noid[id] }.select { |node| destination?(node) }
  rescue Faraday::Error, AtlasRb::Error, JSON::ParserError => e
    Rails.logger.error("IptcDestinations: #{e.class} #{e.message}")
    []
  end

  private

    # A Work child would become the parent of every ingested Work.
    def destination?(node)
      node['klass'] == 'Collection' && !node['tombstoned']
    end
end
