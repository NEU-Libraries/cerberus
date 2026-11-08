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
      permissions = AtlasRb::Resource.permissions(work_noid)
      release = withheld_until(permissions)
      return errors << "#{work_noid}: withheld — under embargo until #{release}" if release

      editors = DerivativeGate.editors_from_permissions(permissions)
      queued_assets(work_noid, entries).each do |asset|
        # Without this the archive serves tier bytes `/downloads/:id` refuses.
        if DerivativeGate.readable?(asset, @ability, editors: editors)
          pack_queued_asset(zip, work_noid, asset, manifest, errors)
        else
          errors << "#{work_noid}: withheld — #{asset[:use].presence || asset.noid} is not available to download"
        end
      end
    rescue AtlasRb::TombstonedError
      errors << withheld_as_removed(work_noid)
    rescue Faraday::Error, JSON::ParserError => e
      errors << "#{work_noid}: assets unavailable — #{e.class}: #{e.message}"
    end

    def queued_assets(work_noid, entries)
      blob_noids = values_for(entries, 'b')
      roles = values_for(entries, 'd')
      AtlasRb::Work.assets(work_noid, nuid: @nuid).select { |asset| queued?(asset, blob_noids, roles) }
    end

    def queued?(asset, blob_noids, roles)
      content_blob?(asset) ? blob_noids.include?(asset.noid) : roles.include?(asset[:role])
    end

    def pack_queued_asset(zip, work_noid, asset, manifest, errors)
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
    # content — so Atlas returns its assets and they would be packed.
    def withheld_until(permissions)
      return nil if @bypass_embargo

      release = permissions&.embargo
      Embargo.active?(release) ? Embargo.release_date(release) : nil
    end
end
