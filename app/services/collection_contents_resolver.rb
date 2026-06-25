# frozen_string_literal: true

# A Collection's member Works as gated Solr documents, in the page-batched shape
# {MetadataExportPacker} consumes. The collection counterpart of the slice of
# SetResolver that bulk export needs: same gated `search_builder` chain (so a
# viewer only ever sees Works they can discover), same `each_content_batch` /
# `contents_count` surface, same {SetResolver::MAX_EXPORT_ROWS} runaway cap.
#
# Direct members only (structural + linked overlay), matching the Collection
# show page's browse semantics (CatalogController#find_children with no query) —
# Works in sub-collections are not pulled. Containers are excluded; only leaf
# Works are "contents".
class CollectionContentsResolver
  # @param valkyrie_id [String] the collection's uuid (Solr uniqueKey form), as
  #   stored in the membership fields. Typically `collection.valkyrie_id`.
  # @param search_service [Blacklight::SearchService] supplies the gated builder
  #   + index (the controller's `search_service`).
  def initialize(valkyrie_id:, search_service:)
    @valkyrie_id = valkyrie_id
    @search_service = search_service
  end

  # @return [Integer] gated tally of the collection's member Works.
  def contents_count
    search(*contents_fqs, rows: 0).total
  end

  # Streams the member Works in pages of gated SolrDocuments, capped at
  # {SetResolver::MAX_EXPORT_ROWS}. Mirrors SetResolver#each_content_batch.
  #
  # @yieldparam docs [Array<SolrDocument>] one page of member Works.
  # @return [void]
  def each_content_batch(batch: 200)
    return if @valkyrie_id.blank?

    start = 0
    loop do
      docs = search(*contents_fqs, rows: batch, start: start,
                    fl: 'id,alternate_ids_ssim').documents
      break if docs.empty?

      yield docs
      start += docs.size
      break if start >= SetResolver::MAX_EXPORT_ROWS
    end
  end

  private

    def contents_fqs
      [MembershipQuery.members_fq([@valkyrie_id], include_linked: true),
       *SetResolver::DEFAULT_TYPE_FILTERS]
    end

    def search(*filter_queries, **extra)
      builder = @search_service.search_builder.with({}).with_filters(*filter_queries)
      builder = builder.merge(**extra) if extra.any?
      Blacklight.default_index.search(builder)
    end
end
