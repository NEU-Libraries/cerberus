# frozen_string_literal: true

# Streams a Set's content Blobs into an already-open zip_kit writer, chunk by
# chunk so memory stays flat regardless of set or file size. Naming, STORE and
# the manifest live in {ZipEntryWriter}. See docs/downloads.md.
class SetZipPacker
  include ZipEntryWriter

  # Every Solr field this packer reads off a member doc; SetResolver builds its
  # `fl` from it. A field read here but not declared here is silently nil, which
  # once disabled the embargo check on every document.
  REQUIRED_DOC_FIELDS = %w[
    id
    alternate_ids_ssim
    embargo_release_date_dtsi
  ].freeze

  # `ability` and `bypass_embargo` are the CALLER's, never the set owner's.
  def initialize(resolver:, nuid:, ability:, bypass_embargo: false)
    @resolver = resolver
    @nuid = nuid
    @ability = ability
    @bypass_embargo = bypass_embargo
  end

  def pack(zip)
    manifest = []
    errors = []

    @resolver.each_content_batch do |docs|
      docs.each { |doc| pack_member(zip, doc, manifest, errors) }
    end

    write_manifest(zip, manifest, errors)
  end

  private

    def pack_member(zip, doc, manifest, errors)
      noid = noid_of(doc)
      return if noid.blank?

      if embargo_withholds_doc?(doc)
        errors << "#{noid}: withheld — under embargo until #{embargo_date_of(doc)}"
        return
      end

      AtlasRb::Work.assets(noid, nuid: @nuid).each do |asset|
        next unless content_blob?(asset)

        if DerivativeGate.readable?(asset, @ability)
          write_asset(zip, noid, asset, manifest, errors)
        else
          errors << "#{noid}: withheld — #{asset[:use].presence || asset.noid} is not available to download"
        end
      end
    end

    # Solr stores the noid in `alternate_ids_ssim` as `id-<noid>`.
    def noid_of(doc)
      Array(doc['alternate_ids_ssim']).first.to_s.delete_prefix('id-').presence
    end

    # The resolver's gated search cannot do this: an embargoed Work is
    # deliberately DISCOVERABLE, so it arrives here like any other member.
    # Without this check the archive hands out bytes `/downloads/:id` refuses.
    def embargo_withholds_doc?(doc)
      return false if @bypass_embargo

      Embargo.active?(embargo_date_of(doc))
    end

    def embargo_date_of(doc)
      Embargo.release_date(Array(doc['embargo_release_date_dtsi']).first)
    end
end
