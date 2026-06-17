# frozen_string_literal: true

# Streams a Set's content into an already-open zip_kit writer, one file at a
# time — each Blob's bytes are pulled from Atlas chunk-by-chunk and written
# straight through, so memory stays flat regardless of set or file size.
#
# CONTENT ONLY: Atlas's `GET /works/:id/assets` already drops metadata FileSets
# and non-downloadable roles; {ZipEntryWriter#content_blob?} drops Delegate
# derivatives (the S/M/L trio carry a `uri`). Naming, STORE, and the manifest
# live in {ZipEntryWriter} (shared with QueueZipPacker). Each work's content
# lands in a per-work folder keyed on its noid (a title slug ran absurdly long).
class SetZipPacker
  include ZipEntryWriter

  def initialize(resolver:, nuid:)
    @resolver = resolver
    @nuid = nuid
  end

  # @param zip [ZipKit::Streamer] an open writer (from `zip_kit_stream`)
  # @return [void]
  def pack(zip)
    manifest = []
    errors = []

    @resolver.each_content_batch do |docs|
      docs.each do |doc|
        noid = noid_of(doc)
        next if noid.blank?

        AtlasRb::Work.assets(noid, nuid: @nuid).each do |asset|
          write_asset(zip, noid, asset, manifest, errors) if content_blob?(asset)
        end
      end
    end

    write_manifest(zip, manifest, errors)
  end

  private

    # Solr stores the noid in `alternate_ids_ssim` as `id-<noid>`.
    def noid_of(doc)
      Array(doc['alternate_ids_ssim']).first.to_s.delete_prefix('id-').presence
    end
end
