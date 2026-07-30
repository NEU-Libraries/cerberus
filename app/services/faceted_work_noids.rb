# frozen_string_literal: true

# Resolves a Usage Analytics facet selection (Content type or Featured
# Content category) to the Work noids it covers.
#
# Deliberately un-gated / system-wide (direct Blacklight.default_index.search
# calls, no SearchBuilder), matching ContainerDescendantsQuery and the rest of
# the impressions reporting stack — NOT a reuse of FeaturedCategory, even
# though the Featured-Content branch mirrors its query shape, because
# FeaturedCategory runs through the gated SearchBuilder chain (scoped to
# whichever admin/delegate happens to be viewing). Admin analytics must count
# every resource regardless of the viewer's own visibility, or the same
# dashboard would report different numbers to an :admin vs an :admin_delegate.
class FacetedWorkNoids < ApplicationService
  MAX_ROWS = 100_000

  # @param type [String] 'content' or 'featured'.
  # @param value [String] the classification label ('Image') or Featured
  #   Content genre label ('Datasets').
  def initialize(type:, value:)
    @type = type.to_s
    @value = value.to_s
    super()
  end

  # @return [Array<String>] matching Work noids (empty if type/value is
  #   unrecognized, blank, or nothing matches).
  def call
    case @type
    when 'content'  then content_work_noids
    when 'featured' then featured_work_noids
    else []
    end
  end

  private

    def content_work_noids
      return [] if @value.blank?

      solr(fields:  'id,alternate_ids_ssim',
           filters: ['internal_resource_tesim:Work', %(classification_ssim:"#{escaped_value}")])
        .filter_map { |doc| doc_noid(doc) }
    end

    # Same shape as FeaturedCategory#showcase_uuids / #works_in, un-gated.
    def featured_work_noids
      return [] if @value.blank?

      uuids = showcase_uuids
      return [] if uuids.empty?

      solr(fields:  'id,alternate_ids_ssim',
           filters: ['internal_resource_tesim:Work', '-tombstoned_bsi:true',
                     MembershipQuery.members_fq(uuids, include_linked: true)])
        .filter_map { |doc| doc_noid(doc) }
    end

    def showcase_uuids
      solr(fields:  'id,title_tsim',
           filters: ['internal_resource_tesim:Collection', 'featured_bsi:true', '-tombstoned_bsi:true',
                     %(title_tsim:"#{escaped_value}")])
        .select { |doc| Array(doc['title_tsim']).first == @value }
        .map(&:id)
    end

    def doc_noid(doc)
      Array(doc['alternate_ids_ssim']).first&.delete_prefix('id-')
    end

    def escaped_value
      @value.gsub(/["\\]/, '')
    end

    def solr(fields:, filters:)
      Blacklight.default_index.search(q: '*:*', fq: filters, rows: MAX_ROWS, fl: fields).documents
    end
end
