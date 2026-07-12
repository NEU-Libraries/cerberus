# frozen_string_literal: true

# Streams a Download Queue (a flat list of individually-chosen downloads) into an
# open zip_kit writer. Unlike SetZipPacker — which resolves whole works and packs
# all their content — this packs only the *queued* items, grouped into a per-work
# folder (`<work_noid>/`). Each item is either a content Blob (`'b'`) or an IIIF
# derivative rendition (`'d'`); both are packed via ZipEntryWriter, the derivative
# fetched over HTTP from its (signed, internal-host) gated Cantaloupe URL.
#
# Gating: the queue is an explicit user-chosen list, so there's no Solr step;
# `Work.assets(nuid:)` re-checks at Atlas per work (anon ⇒ public only), and an
# item queued-then-restricted/removed simply isn't returned → skipped.
class QueueZipPacker
  include ZipEntryWriter

  # @param items [Array<Hash>] queue entries: { 'w' => work_noid, 'b' => blob_noid }
  #   for a Blob, or { 'w' => work_noid, 'd' => use } for a derivative rendition.
  # @param nuid [String, nil] acting NUID (nil for anonymous)
  def initialize(items:, nuid:)
    @items = items
    @nuid = nuid
  end

  def pack(zip)
    manifest = []
    errors = []

    @items.group_by { |item| item['w'] }.each do |work_noid, entries|
      pack_work(zip, work_noid, entries, manifest, errors)
    end

    write_manifest(zip, manifest, errors)
  end

  private

    # Pack one work's queued items: its content Blobs by noid, its derivative
    # renditions by use. Work.assets(nuid:) is the per-work re-authorization — an
    # item queued-then-restricted just isn't returned. (In the elsif, the asset
    # is uri-backed, i.e. a delegate, since it wasn't a content_blob?.)
    def pack_work(zip, work_noid, entries, manifest, errors)
      blob_noids = values_for(entries, 'b')
      uses = values_for(entries, 'd')

      AtlasRb::Work.assets(work_noid, nuid: @nuid).each do |asset|
        if content_blob?(asset)
          write_asset(zip, work_noid, asset, manifest, errors) if blob_noids.include?(asset.noid)
        elsif uses.include?(asset[:use])
          write_derivative(zip, work_noid, asset, manifest, errors)
        end
      end
    rescue Faraday::Error, JSON::ParserError => e
      errors << "#{work_noid}: assets unavailable — #{e.class}: #{e.message}"
    end

    # The set of a queue-entry key's values (blob noids for 'b', uses for 'd').
    def values_for(entries, key)
      entries.filter_map { |entry| entry[key] }.to_set
    end
end
