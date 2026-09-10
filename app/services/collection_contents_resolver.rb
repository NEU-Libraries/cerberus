# frozen_string_literal: true

# A Collection's member Works as gated Solr documents, in the page-batched shape
# {MetadataExportPacker} consumes. See docs/discovery.md.
#
# Gated: every query runs through the controller's `search_service.search_builder`,
# so a viewer only ever sees Works they can discover.
class CollectionContentsResolver
  def initialize(valkyrie_id:, search_service:)
    @valkyrie_id = valkyrie_id
    @search_service = search_service
  end

  def contents_count
    search(*contents_fqs, rows: 0).total
  end

  # `fl` is taken from the packer rather than written out here, and the two must
  # not drift. A field the packer reads and the query does not fetch is an error
  # nowhere: the document has no value, the manifest gets a blank cell, and
  # re-loading that manifest writes the blank back over the record.
  def each_content_batch(batch: 200)
    return if @valkyrie_id.blank?

    start = 0
    loop do
      docs = search(*contents_fqs, rows: batch, start: start,
                    fl: MetadataExportPacker::REQUIRED_DOC_FIELDS.join(',')).documents
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
      Blacklight.default_index.search(params: builder)
    end
end
