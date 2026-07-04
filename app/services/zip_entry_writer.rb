# frozen_string_literal: true

# Shared internals for the streaming-zip packers (SetZipPacker, QueueZipPacker).
# They differ only in how they enumerate what to pack; this keeps the per-asset
# write — STORE compression, the labeled consumer-facing naming, manifest
# accrual, and mid-stream error capture — identical and in one place so they
# can't drift. Folder layout is the caller's choice (both use the work noid).
module ZipEntryWriter
  private

    # Stream one content Blob into `<folder>/<labeled-filename>`, chunk-by-chunk
    # from Atlas (flat memory). STORE, not deflate: DRS payloads (JP2/PDF/images/
    # curated zips) are already compressed, so deflating burns CPU for ~0 gain —
    # do NOT switch to write_file/write_deflated_file. A fetch failure mid-stream
    # is recorded (the archive can't be un-sent once headers are out), not raised.
    def write_asset(zip, folder, asset, manifest, errors)
      entry = "#{folder}/#{entry_filename(asset)}"
      zip.write_stored_file(entry) do |sink|
        AtlasRb::Blob.content(asset.noid) { |chunk| sink << chunk }
      end
      manifest << entry
    rescue Faraday::Error, JSON::ParserError => e
      errors << "#{folder}: #{asset.noid} failed — #{e.class}: #{e.message}"
    end

    # Blob-backed content only — Delegates (the downloadable S/M/L derivatives)
    # are pointer-only and carry a `uri`; Blobs do not.
    def content_blob?(asset)
      asset[:uri].blank?
    end

    # Labeled `<prefix><noid>.<ext>` when Atlas serves it, else a neutral
    # `<noid>.<ext>` — collision-free, never the (often offputting) original_filename.
    def entry_filename(asset)
      asset[:filename].presence || "#{asset.noid}.#{extension_of(asset)}"
    end

    # Extension only (not the name): from original_filename, else a mime guess, else bin.
    def extension_of(asset)
      from_name = asset[:original_filename].to_s[/\.([^.]+)\z/, 1]
      from_mime = Rack::Mime::MIME_TYPES.key(asset[:mime_type].to_s)&.delete_prefix('.')
      from_name.presence || from_mime.presence || 'bin'
    end

    # Trailing entries, written last so a truncated/partial archive is self-describing.
    def write_manifest(zip, manifest, errors)
      write_text(zip, 'MANIFEST.txt', manifest_body(manifest))
      write_text(zip, 'ERRORS.txt', errors.join("\n")) if errors.any?
    end

    def manifest_body(entries)
      (["# #{entries.size} file(s)", ''] + entries).join("\n")
    end

    def write_text(zip, name, body)
      zip.write_stored_file(name) { |sink| sink << body.to_s }
    end
end
