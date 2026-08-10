# frozen_string_literal: true

# Streams a Download Queue (a flat list of individually-chosen downloads) into an
# open zip_kit writer. Unlike SetZipPacker — which resolves whole works and packs
# all their content — this packs only the *queued* items, grouped into a per-work
# folder (`<work_noid>/`). Each item is either a content Blob (`'b'`) or an IIIF
# derivative rendition (`'d'`); both are packed via ZipEntryWriter, the derivative
# fetched over HTTP from its (signed, internal-host) gated Cantaloupe URL.
#
# Gating, in three parts. `Work.assets(nuid:)` re-checks READ at Atlas per work
# (anon ⇒ public only), so an item queued-then-restricted simply isn't returned.
# That is not sufficient on its own, twice over:
#
# * An embargoed Work is deliberately readable — public metadata, withheld
#   content — so its assets come back and would be packed. The embargo is
#   therefore checked here too, per work.
# * Atlas re-authorizes at the WORK level, not the tier level. The per-asset gate
#   rides the returned entries as advisory `gated` / `permission` for the display
#   layer to enforce, so a restricted tier — a Streaming Only video, a gated
#   master — arrives here looking like any other asset. Without the DerivativeGate
#   check below, the archive hands out bytes `/downloads/:id` refuses.
class QueueZipPacker
  include ZipEntryWriter

  # @param items [Array<Hash>] queue entries: { 'w' => work_noid, 'b' => blob_noid }
  #   for a Blob, or { 'w' => work_noid, 'd' => use } for a derivative rendition.
  # @param nuid [String, nil] acting NUID (nil for anonymous)
  # @param ability [Ability] the CALLER's ability, for the per-asset tier gate.
  # @param bypass_embargo [Boolean] the CALLER's right to receive withheld content.
  def initialize(items:, nuid:, ability:, bypass_embargo: false)
    @items = items
    @nuid = nuid
    @ability = ability
    @bypass_embargo = bypass_embargo
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
      if (release = withheld_until(work_noid))
        errors << "#{work_noid}: withheld — under embargo until #{release}"
        return
      end

      blob_noids = values_for(entries, 'b')
      uses = values_for(entries, 'd')

      AtlasRb::Work.assets(work_noid, nuid: @nuid).each do |asset|
        # Named rather than skipped in silence, matching how an embargoed member
        # is reported: someone who queued a file and did not get it should be
        # able to see which, and that access — not a failure — is the reason.
        wanted = content_blob?(asset) ? blob_noids.include?(asset.noid) : uses.include?(asset[:use])
        next unless wanted

        unless DerivativeGate.readable?(asset, @ability)
          errors << "#{work_noid}: withheld — #{asset[:use].presence || asset.noid} is not available to download"
          next
        end

        if content_blob?(asset)
          write_asset(zip, work_noid, asset, manifest, errors)
        else
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

    # The release date when this work's content is withheld from THIS caller,
    # else nil. Unlike SetZipPacker there is no Solr doc to read the date off —
    # the queue is a bare list of noids — so this costs one Atlas call per
    # distinct work. Acceptable: a queue is user-curated and short, and the
    # alternative is handing out embargoed bytes.
    def withheld_until(work_noid)
      return nil if @bypass_embargo

      release = AtlasRb::Resource.permissions(work_noid)&.embargo
      # The stored value is a timestamp; the manifest is read by a person, so
      # give them the date and not `2029-12-31T00:00:00+00:00`.
      Embargo.active?(release) ? Embargo.release_date(release) : nil
    end
end
