# frozen_string_literal: true

# The genre showcase a Work is published in, and the other showcases of the same
# community it could move to. Backs the Work Edit page's Showcase category
# choice. See docs/discovery.md.
#
# Atlas's find_many digest carries neither `featured` nor a parent, so both come
# from Solr, through the gated SearchBuilder chain like ShowcaseFinder.
class WorkShowcase < ApplicationService
  Placement = Struct.new(:showcase_noid, :genre, :community_noid, :options, keyword_init: true)

  def initialize(scope:, work_noid:)
    @scope = scope
    @work_noid = work_noid
    super()
  end

  # @return [Placement, nil] nil when the Work is in no genre showcase.
  def call
    linked = Array(AtlasRb::Work.linked_members(@work_noid))
    return nil if linked.empty?

    showcase = current_showcase(linked)
    return nil if showcase.nil?

    community_noid = parent_noid(showcase)
    return nil if community_noid.nil?

    Placement.new(showcase_noid: showcase.to_param, genre: Array(showcase['title_tsim']).first,
                  community_noid: community_noid,
                  options: ShowcaseFinder.call(scope: @scope, community_noid: community_noid))
  end

  private

    # Publishing links a Work into one showcase. A Work an admin has also linked
    # into a second one reports the first Solr returns.
    def current_showcase(linked_noids)
      labels = FeaturedContent.genre_labels.to_set
      ids = linked_noids.map { |noid| "id-#{noid}" }.join(',')
      search('internal_resource_tesim:Collection', 'featured_bsi:true', "{!terms f=alternate_ids_ssim}#{ids}")
        .documents.find { |doc| labels.include?(Array(doc['title_tsim']).first) }
    end

    def parent_noid(showcase)
      uuid = showcase[MembershipQuery::STRUCTURAL_FIELD].to_s.delete_prefix('id-')
      return nil if uuid.blank?

      search(MembershipQuery.identity_fq([uuid])).documents.first&.to_param
    end

    def search(*filter_queries)
      builder = SearchBuilder.new(@scope).with({})
                             .with_filters('-tombstoned_bsi:true', *filter_queries).merge(rows: 50)
      Blacklight.default_index.search(params: builder)
    end
end
