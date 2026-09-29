# frozen_string_literal: true

# The structural parent of each document on one page of results, in one Solr
# read, for the tombstone registry's Parent column. See docs/admin.md.
class StructuralParents < ApplicationService
  FIELDS = 'id,title_tsim,alternate_ids_ssim,internal_resource_tesim,tombstoned_bsi'

  def initialize(documents:)
    @documents = Array(documents)
    super()
  end

  # @return [Hash{String => SolrDocument}] parent documents keyed by uuid.
  def call
    uuids = @documents.filter_map { |doc| self.class.parent_uuid(doc) }.uniq
    return {} if uuids.empty?

    # The raw index, not a SearchBuilder: the catalog's default fq drops
    # tombstoned documents, and a tombstoned parent is the one an admin most
    # needs to see, since it has to be restored first.
    Blacklight.default_index.search(q: '*:*', fq: [MembershipQuery.identity_fq(uuids)],
                                    rows: uuids.size, fl: FIELDS)
              .documents.index_by(&:id)
  rescue Blacklight::Exceptions::InvalidRequest, Faraday::Error => e
    Rails.logger.error("StructuralParents: #{e.class} #{e.message}")
    {}
  end

  # A top-level Community has none.
  def self.parent_uuid(doc)
    doc[MembershipQuery::STRUCTURAL_FIELD].to_s.delete_prefix('id-').presence
  end
end
