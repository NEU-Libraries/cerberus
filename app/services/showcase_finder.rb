# frozen_string_literal: true

# Resolves a community's genre "showcase" Collections — the featured containers
# provisioned by CommunitiesController#provision_showcases — for the deposit
# fork's publish branch. Two uses:
#
#   ShowcaseFinder.call(scope:, community_noid:)
#     => { "Presentations" => "<noid>", "Datasets" => "<noid>", ... }
#        every showcase that exists under the community, keyed by genre label
#        (what WorksController#new offers as publish categories).
#
#   ShowcaseFinder.call(scope:, community_noid:, genre_label: "Datasets")
#     => "<noid>"  (or nil)
#        the single showcase NOID for one genre — the linked-member edge target
#        WorksController#create writes to on publish.
#
# Uses the same `Blacklight.default_index.search(SearchBuilder.new(scope))`
# idiom as ResourceSearch, so it runs through the gated SearchBuilder chain
# (scope = the controller, supplying current_user) — a private/embargoed
# showcase the depositor can't see is never offered as a publish target.
# Showcases are matched within the community's subtree (descendants_fq on the
# community NOID), restricted to featured Collections whose title is one of the
# shared scholarly genre labels.
class ShowcaseFinder < ApplicationService
  MAX_SHOWCASES = 50

  # @param scope [#blacklight_config, #current_user] the controller.
  # @param community_noid [String] the community whose showcases to resolve.
  # @param genre_label [String, nil] when given, return just that genre's
  #   showcase NOID; otherwise return the full {label => noid} map.
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

    # { genre_label => showcase_noid } for the community's featured Collections
    # whose title is a known genre. A community has one showcase per genre, so
    # the map is small; last-writer-wins on the (not expected) duplicate title.
    def fetch_showcases
      builder = SearchBuilder.new(@scope).with({}).with_filters(
        'internal_resource_tesim:Collection',
        'featured_bsi:true',
        '-tombstoned_bsi:true',
        MembershipQuery.descendants_fq(@community_noid)
      ).merge(rows: MAX_SHOWCASES)

      labels = FeaturedContent.genre_labels.to_set
      Blacklight.default_index.search(builder).documents.each_with_object({}) do |doc, map|
        title = Array(doc['title_tsim']).first
        map[title] = doc.to_param if title.present? && labels.include?(title)
      end
    end
end
