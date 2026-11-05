# frozen_string_literal: true

# The genre showcases a Work is published in, one per community, and for each
# the other showcases of that community it could move to. Backs the Work Edit
# page's Showcase section. See docs/discovery.md.
#
# Atlas's find_many digest carries neither `featured` nor a parent, so both come
# from Solr, through the gated SearchBuilder chain like ShowcaseFinder.
class WorkShowcase < ApplicationService
  Placement = Struct.new(:showcase_noid, :genre, :community_noid, :community_title, :options, keyword_init: true)

  def initialize(scope:, work_noid:)
    @scope = scope
    @work_noid = work_noid
    super()
  end

  # @return [Array<Placement>] empty when the Work is in no genre showcase.
  def call
    linked = Array(AtlasRb::Work.linked_members(@work_noid))
    return [] if linked.empty?

    showcases = genre_showcases(linked)
    return [] if showcases.empty?

    communities = parents(showcases)
    showcases.filter_map do |showcase|
      community = communities[parent_uuid(showcase)]
      placement(showcase, community) if community
    end
  end

  private

    def placement(showcase, community)
      Placement.new(showcase_noid: showcase.to_param, genre: Array(showcase['title_tsim']).first,
                    community_noid: community.to_param, community_title: Array(community['title_tsim']).first,
                    options: ShowcaseFinder.call(scope: @scope, community_noid: community.to_param))
    end

    def genre_showcases(linked_noids)
      labels = FeaturedContent.genre_labels.to_set
      ids = linked_noids.map { |noid| "id-#{noid}" }.join(',')
      search('internal_resource_tesim:Collection', 'featured_bsi:true', "{!terms f=alternate_ids_ssim}#{ids}")
        .documents.select { |doc| labels.include?(Array(doc['title_tsim']).first) }
    end

    # One query for every placement's community, keyed by Solr id.
    def parents(showcases)
      uuids = showcases.map { |showcase| parent_uuid(showcase) }.compact_blank.uniq
      return {} if uuids.empty?

      search(MembershipQuery.identity_fq(uuids)).documents.index_by(&:id)
    end

    def parent_uuid(showcase)
      showcase[MembershipQuery::STRUCTURAL_FIELD].to_s.delete_prefix('id-')
    end

    def search(*filter_queries)
      builder = SearchBuilder.new(@scope).with({})
                             .with_filters('-tombstoned_bsi:true', *filter_queries).merge(rows: 50)
      Blacklight.default_index.search(params: builder)
    end
end
