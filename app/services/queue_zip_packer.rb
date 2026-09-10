# frozen_string_literal: true

# Streams a Download Queue's individually-chosen items into an open zip_kit
# writer, grouped into a per-work folder. `Work.assets(nuid:)` re-authorizes
# each work, but that alone is NOT enough to gate an entry — the embargo and
# per-asset checks below are both load-bearing. See docs/downloads.md.
class QueueZipPacker
  include ZipEntryWriter

  # `ability` and `bypass_embargo` are the CALLER's, never the queue owner's.
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

    def pack_work(zip, work_noid, entries, manifest, errors)
      if (release = withheld_until(work_noid))
        errors << "#{work_noid}: withheld — under embargo until #{release}"
        return
      end

      blob_noids = values_for(entries, 'b')
      uses = values_for(entries, 'd')

      AtlasRb::Work.assets(work_noid, nuid: @nuid).each do |asset|
        next unless queued?(asset, blob_noids, uses)

        pack_queued_asset(zip, work_noid, asset, manifest, errors)
      end
    rescue Faraday::Error, JSON::ParserError => e
      errors << "#{work_noid}: assets unavailable — #{e.class}: #{e.message}"
    end

    def queued?(asset, blob_noids, uses)
      content_blob?(asset) ? blob_noids.include?(asset.noid) : uses.include?(asset[:use])
    end

    # Atlas re-authorizes at the WORK level only; the per-asset gate rides the
    # returned entries as advisory, so a restricted tier arrives looking like any
    # other asset. Without DerivativeGate the archive serves bytes
    # `/downloads/:id` refuses.
    def pack_queued_asset(zip, work_noid, asset, manifest, errors)
      unless DerivativeGate.readable?(asset, @ability)
        errors << "#{work_noid}: withheld — #{asset[:use].presence || asset.noid} is not available to download"
        return
      end

      if content_blob?(asset)
        write_asset(zip, work_noid, asset, manifest, errors)
      else
        write_derivative(zip, work_noid, asset, manifest, errors)
      end
    end

    def values_for(entries, key)
      entries.filter_map { |entry| entry[key] }.to_set
    end

    # An embargoed Work is deliberately READABLE — public metadata, withheld
    # content — so Atlas returns its assets and they would be packed. Costs one
    # Atlas call per distinct work; the alternative is serving embargoed bytes.
    def withheld_until(work_noid)
      return nil if @bypass_embargo

      release = AtlasRb::Resource.permissions(work_noid)&.embargo
      Embargo.active?(release) ? Embargo.release_date(release) : nil
    end
end
