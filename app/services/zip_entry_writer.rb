# frozen_string_literal: true

require 'csv'

# Shared per-asset write for the streaming-zip packers (SetZipPacker,
# QueueZipPacker, BlobZipPacker), which differ only in what they enumerate.
# Folder is the caller's choice; nil puts the entry at the archive root.
# See docs/downloads.md.
module ZipEntryWriter
  private

    # Chunk-by-chunk from Atlas: never read a Blob into memory. STORE, not
    # deflate — do NOT switch to write_file/write_deflated_file. A mid-stream
    # failure is recorded, never raised; the archive can't be un-sent.
    def write_asset(zip, folder, asset, manifest, errors)
      name = entry_filename(asset)
      zip.write_stored_file([folder, name].compact.join('/')) do |sink|
        AtlasRb::Blob.content(asset.noid) { |chunk| sink << chunk }
      end
      manifest << { identifier: folder, filename: name }
    rescue Faraday::Error, JSON::ParserError => e
      errors << "#{folder}: #{asset.noid} failed — #{e.class}: #{e.message}"
    end

    # A delegate is pointer-only, so its bytes come over HTTP from the gated
    # Cantaloupe host and the URL must be signed. on_data streams chunks into the
    # sink — never buffer the whole JPEG. A mid-stream failure is recorded, not
    # raised.
    def write_derivative(zip, folder, delegate, manifest, errors)
      name = DerivativeCreator.filename(delegate[:role], folder)
      url = IiifSigner.sign_url(internal_iiif_url(delegate[:uri]))
      zip.write_stored_file([folder, name].compact.join('/')) do |sink|
        Faraday.get(url) { |req| req.options.on_data = proc { |chunk, _received| sink << chunk } }
      end
      manifest << { identifier: folder, filename: name }
    rescue Faraday::Error => e
      errors << "#{folder}: #{delegate[:use]} failed — #{e.class}: #{e.message}"
    end

    # Delegates are pointer-only and carry a `uri`; content Blobs do not.
    def content_blob?(asset)
      asset[:uri].blank?
    end

    # Delegate URIs carry Cantaloupe's PUBLIC host, but the packer runs
    # server-side. Only the host changes; the signed path is unaffected.
    def internal_iiif_url(uri)
      internal = Rails.application.config.x.cerberus.iiif_internal_host
      public_host = Rails.application.config.iiif_host
      return uri if internal.blank? || public_host.blank?

      uri.sub(/\A#{Regexp.escape(public_host)}/, internal)
    end

    # Never name an entry from original_filename: prefer Atlas's labeled name,
    # else a neutral `<noid>.<ext>`.
    def entry_filename(asset)
      asset[:filename].presence || "#{asset.noid}.#{extension_of(asset)}"
    end

    def extension_of(asset)
      from_name = asset[:original_filename].to_s[/\.([^.]+)\z/, 1]
      from_mime = Rack::Mime::MIME_TYPES.key(asset[:mime_type].to_s)&.delete_prefix('.')
      from_name.presence || from_mime.presence || 'bin'
    end

    # Written last, so a truncated archive is still self-describing.
    def write_manifest(zip, manifest, errors)
      write_text(zip, 'inventory.csv', inventory_csv(manifest))
      write_text(zip, 'ERRORS.txt', errors.join("\n")) if errors.any?
    end

    # One row per packed file; the identifier is the Work's NOID, which is also
    # the file's folder.
    def inventory_csv(entries)
      handles = Hash.new { |cache, noid| cache[noid] = work_handle_url(noid) }
      CSV.generate do |csv|
        csv << %w[identifier filename handle]
        entries.each { |row| csv << [row[:identifier], row[:filename], handles[row[:identifier]]] }
      end
    end

    # The handle is on the Work record only, not in Solr, so this is one read per
    # Work. A Work without a handle, or a failed read, leaves the cell blank:
    # the files are already sent.
    def work_handle_url(noid)
      return nil if noid.blank?

      ApplicationController.helpers.handle_url(AtlasRb::Work.find(noid, nuid: @nuid)&.handle)
    rescue AtlasRb::Error, Faraday::Error, JSON::ParserError
      nil
    end

    def write_text(zip, name, body)
      zip.write_stored_file(name) { |sink| sink << body.to_s }
    end
end
