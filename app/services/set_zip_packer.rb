# frozen_string_literal: true

# Streams a Set's content into an already-open zip_kit writer, one file at a
# time — each Blob's bytes are pulled from Atlas chunk-by-chunk and written
# straight through, so memory stays flat regardless of set or file size
# (never a whole file, let alone the whole archive, in memory).
#
# CONTENT ONLY, by two complementary filters:
#   - Atlas's `GET /works/:id/assets` already drops metadata FileSets and
#     non-downloadable roles (thumbnails/preview), so MODS/METS never arrive.
#   - {#content_blob?} drops Delegate-backed derivatives (the downloadable
#     S/M/L trio), which carry a `uri` rather than held bytes.
#
# Naming is the labeled, consumer-facing scheme: a per-work folder named by
# the work `<noid>/` plus the labeled `<prefix><noid>.<ext>` filename.
# `original_filename` is deliberately NEVER surfaced — deposited names are
# preservation/curation data, often confusing or offputting; the cases where
# filenames carry meaning (e.g. inter-referencing science datasets) are
# handled upstream by guiding uploaders to deposit a single curated zip, which
# then streams in here as one ordinary Blob.
class SetZipPacker
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

        pack_work(zip, noid, manifest, errors)
      end
    end

    # Trailing entries, written last: a partial/truncated archive (a member
    # fetch dying mid-stream after headers are sent is unrecoverable) is at
    # least self-describing.
    write_text(zip, 'MANIFEST.txt', manifest_body(manifest))
    write_text(zip, 'ERRORS.txt', errors.join("\n")) if errors.any?
  end

  private

    def pack_work(zip, noid, manifest, errors)
      # Per-work folder keyed on the noid alone — short, unique, stable.
      # (A title slug was tried but ran absurdly long, e.g.
      # "what-s-new-how-we-respond-to-disaster-episode-1-<noid>/".)
      AtlasRb::Work.assets(noid, nuid: @nuid).each do |asset|
        next unless content_blob?(asset)

        entry = "#{noid}/#{entry_filename(asset)}"
        # STORE, not deflate: DRS payloads (JP2/PDF/images/curated zips) are
        # already compressed, so deflating burns CPU for ~0 gain and slows the
        # stream. Do NOT switch this to write_file/write_deflated_file.
        zip.write_stored_file(entry) do |sink|
          AtlasRb::Blob.content(asset.noid) { |chunk| sink << chunk }
        end
        manifest << entry
      rescue Faraday::Error, JSON::ParserError => e
        errors << "#{noid}: #{asset.noid} failed — #{e.class}: #{e.message}"
      end
    end

    # Blob-backed content only. Delegates (the downloadable S/M/L derivatives)
    # are pointer-only and carry a `uri`; Blobs do not.
    def content_blob?(asset)
      asset[:uri].blank?
    end

    # Labeled filename (`<prefix><noid>.<ext>`) when Atlas exposes it; until
    # the assets endpoint serializes `filename` (gap report), fall back to a
    # neutral `<noid>.<ext>` — collision-free and never the original_filename.
    def entry_filename(asset)
      asset[:filename].presence || "#{asset.noid}.#{extension_of(asset)}"
    end

    # Extension only (not the name): safe to take from original_filename — an
    # extension isn't the offputting part — else a mime guess, else `bin`.
    def extension_of(asset)
      from_name = asset[:original_filename].to_s[/\.([^.]+)\z/, 1]
      from_mime = Rack::Mime::MIME_TYPES.key(asset[:mime_type].to_s)&.delete_prefix('.')
      from_name.presence || from_mime.presence || 'bin'
    end

    # Solr stores the noid in `alternate_ids_ssim` as `id-<noid>`.
    def noid_of(doc)
      Array(doc['alternate_ids_ssim']).first.to_s.delete_prefix('id-').presence
    end

    def manifest_body(entries)
      header = ["# #{entries.size} file(s)", '']
      (header + entries).join("\n")
    end

    def write_text(zip, name, body)
      zip.write_stored_file(name) { |sink| sink << body.to_s }
    end
end
