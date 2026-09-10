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

    def fetch_showcases
      builder = SearchBuilder.new(@scope).with({}).with_filters(
        'internal_resource_tesim:Collection',
        'featured_bsi:true',
        '-tombstoned_bsi:true',
        MembershipQuery.descendants_fq(@community_noid)
      ).merge(rows: MAX_SHOWCASES)

      labels = FeaturedContent.genre_labels.to_set
      Blacklight.default_index.search(params: builder).documents.each_with_object({}) do |doc, map|
        title = Array(doc['title_tsim']).first
        map[title] = doc.to_param if title.present? && labels.include?(title)
      end
    end
end
