# frozen_string_literal: true

# Resolves a community's genre showcase Collections for the deposit fork's
# publish branch. See docs/discovery.md.
#
# Gated: the search runs through the {SearchBuilder} chain with the controller
# as scope, so a showcase the depositor cannot discover is never offered as a
# publish target.
class ShowcaseFinder < ApplicationService
  MAX_SHOWCASES = 50

  def initialize(scope:, community_noid:, genre_label: nil)
    @scope = scope
    @community_noid = community_noid
    @genre_label = genre_label
    super()
  end

  def call
    return @genre_label.blank? ? {} : nil if @community_noid.blank?

    showcases = fetch_showcases
    return showcases if @genre_label.blank?

    showcases[@genre_label]
  end

  private

    # Direct children only. The subtree also holds every descendant community's
    # showcases, which share the same genre titles, so a lookup at the root
    # would resolve "Datasets" to whichever showcase Solr happened to list last.
    def fetch_showcases
      community_uuid = resolve_uuid(@community_noid)
      return {} if community_uuid.nil?

      labels = FeaturedContent.genre_labels.to_set
      search('internal_resource_tesim:Collection', 'featured_bsi:true',
             MembershipQuery.members_fq([community_uuid]), rows: MAX_SHOWCASES)
        .documents.each_with_object({}) do |doc, map|
          title = Array(doc['title_tsim']).first
          map[title] = doc.to_param if title.present? && labels.include?(title)
        end
    end

    # The structural parent edge holds the parent's uuid, and the caller has
    # only its noid. Solr stores the noid in `alternate_ids_ssim` as `id-<noid>`.
    def resolve_uuid(noid)
      search("{!terms f=alternate_ids_ssim}id-#{noid}", rows: 1, fl: 'id').documents.first&.id
    end

    def search(*filter_queries, **extra)
      builder = SearchBuilder.new(@scope).with({})
                             .with_filters('-tombstoned_bsi:true', *filter_queries).merge(**extra)
      Blacklight.default_index.search(params: builder)
    end
end
