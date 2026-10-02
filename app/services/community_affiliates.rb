# frozen_string_literal: true

# The People affiliated with one community, for the admin People tab on its
# Edit page. The same filter as the public Faculty & Staff browse, read from
# Solr because a Person holds its affiliations and nothing indexes the reverse
# in Atlas.
class CommunityAffiliates < ApplicationService
  # A community's people run to the hundreds at most; past this the tab says
  # it is showing the first LIMIT rather than paging.
  LIMIT = 500
  FIELDS = 'id,noid_ssi,display_name_ssi,nuid_ssi'

  Result = Struct.new(:people, :total)

  def initialize(community_noid:)
    @community_noid = community_noid.to_s
    super()
  end

  # @return [Result] people as SolrDocuments in name order, and the full count.
  def call
    response = Blacklight.default_index.search(
      q: '*:*', fq: ['type_ssim:Person', %(affiliated_community_ids_ssim:"#{@community_noid.gsub(/["\\]/, '')}")],
      sort: 'display_name_ssi asc', rows: LIMIT, fl: FIELDS
    )
    Result.new(response.documents, response.total)
  end
end
