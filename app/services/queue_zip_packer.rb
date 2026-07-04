# frozen_string_literal: true

# Streams a Download Queue (a flat list of individually-chosen content Blobs)
# into an open zip_kit writer. Unlike SetZipPacker — which resolves whole works
# and packs all their content — this packs only the *queued* blobs, grouped into
# a per-work folder (`<work_noid>/`). Shares all the per-asset write/naming/
# manifest logic via ZipEntryWriter.
#
# Gating: the queue is an explicit user-chosen list, so there's no Solr step;
# `Work.assets(nuid:)` re-checks at Atlas per work (anon ⇒ public only), and a
# blob queued-then-restricted/removed simply isn't returned → skipped.
class QueueZipPacker
  include ZipEntryWriter

  # @param items [Array<Hash>] queue entries: { 'w' => work_noid, 'b' => blob_noid }
  # @param nuid [String, nil] acting NUID (nil for anonymous)
  def initialize(items:, nuid:)
    @items = items
    @nuid = nuid
  end

  def pack(zip)
    manifest = []
    errors = []

    blob_noids_by_work.each do |work_noid, blob_noids|
      assets = AtlasRb::Work.assets(work_noid, nuid: @nuid)
      assets.each do |asset|
        next unless content_blob?(asset) && blob_noids.include?(asset.noid)

        write_asset(zip, work_noid, asset, manifest, errors)
      end
    rescue Faraday::Error, JSON::ParserError => e
      errors << "#{work_noid}: assets unavailable — #{e.class}: #{e.message}"
    end

    write_manifest(zip, manifest, errors)
  end

  private

    # { work_noid => Set[blob_noid, ...] }, preserving each work's queued blobs.
    def blob_noids_by_work
      @items.group_by { |i| i['w'] }
            .transform_values { |entries| entries.to_set { |i| i['b'] } }
    end
end
