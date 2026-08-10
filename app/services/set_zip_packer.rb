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

  # Every Solr field this packer reads off a member doc. SetResolver builds its
  # `fl` from this list, so a new field lands in the query by declaring it here.
  # Keeping the two in step by hand is what let the embargo check read nil on
  # every document — the resolver was still fetching "just the noid".
  REQUIRED_DOC_FIELDS = %w[
    id
    alternate_ids_ssim
    embargo_release_date_dtsi
  ].freeze

  # @param ability [Ability] the CALLER's ability. Atlas re-authorizes a member at
  #   the WORK level; the per-asset derivative gate rides its assets as advisory
  #   `gated` / `permission` for the display layer to enforce, so a restricted
  #   tier — a Streaming Only video, a gated master — reaches here looking like
  #   any other asset and has to be checked.
  def initialize(resolver:, nuid:, ability:, bypass_embargo: false)
    @resolver = resolver
    @nuid = nuid
    @ability = ability
    @bypass_embargo = bypass_embargo
  end

  # @param zip [ZipKit::Streamer] an open writer (from `zip_kit_stream`)
  # @return [void]
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

      # Named in the manifest rather than dropped in silence: someone who asked
      # for a set of twelve and got eleven files should be able to see which was
      # held back, and why.
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

    # An embargoed member is skipped, not packed. The resolver's gated search
    # cannot do this for us: an embargoed Work is deliberately DISCOVERABLE —
    # its metadata stays public and only its content is withheld — so it passes
    # discovery gating and arrives here like any other member. Without this the
    # archive is assembled with the set OWNER's reach and hands an anonymous
    # requester bytes that `/downloads/:id` refuses them.
    #
    # The check is free: the embargo date is already on the Solr doc, so no
    # extra Atlas round-trip per member.
    def embargo_withholds_doc?(doc)
      return false if @bypass_embargo

      Embargo.active?(embargo_date_of(doc))
    end

    # The stored value is a timestamp; the manifest is read by a person, so give
    # them the date and not `2029-12-31T00:00:00+00:00`.
    def embargo_date_of(doc)
      Embargo.release_date(Array(doc['embargo_release_date_dtsi']).first)
    end
end
