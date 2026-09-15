# frozen_string_literal: true

# Turns Atlas's marked MODS display values into links to the catalog facet that
# browses them. Atlas states what a value IS — its axis, its exact indexed
# string, its authority — and this decides whether and where it links.
# See docs/discovery.md.
class MODSBrowseLinks < ApplicationService
  # Atlas's semantic axis => the Solr facet field that browses it. Atlas emits
  # `publisher`, `place_of_publication` and `photo_category` too; their absence
  # here is the decision, not an oversight — see docs/discovery.md.
  AXES = {
    'topic'                  => 'subject_ssim',
    'geographic'             => 'subject_geo_ssim',
    'temporal'               => 'subject_era_ssim',
    'personal_name_subject'  => 'subject_person_ssim',
    'corporate_name_subject' => 'subject_corporate_ssim',
    'genre'                  => 'genre_ssim',
    'creator'                => 'creator_ssim',
    'contributor'            => 'contributor_ssim',
    'language'               => 'language_ssim'
  }.freeze

  MARKER = '[data-browse-axis]'

  # @param html [String, nil] Atlas's MODS display fragment.
  # @param facet_fields [Enumerable<String>] the facet fields CatalogController
  #   configures, so a facet dropped from the config stops producing links
  #   without a second list to remember.
  def initialize(html:, facet_fields:)
    @html = html
    @facet_fields = Array(facet_fields).map(&:to_s)
    super()
  end

  # @return [String, nil] the fragment with qualifying values wrapped in links,
  #   everything else untouched. nil in, nil out — a resource with no MODS
  #   renders no block.
  def call
    return @html if @html.blank?

    fragment = Nokogiri::HTML5.fragment(@html)
    fragment.css(MARKER).each { |node| link!(node) }
    fragment.to_html
  end

  private

    # Three predicates, deliberately not collapsed: the facet-target test is a
    # correctness requirement, and the other two are policy that will move.
    def link!(node)
      field = AXES[node['data-browse-axis']]
      return unless field && @facet_fields.include?(field)
      return if node['data-browse-authority'].blank?

      value = node['data-browse-value']
      return if value.blank?

      node.inner_html = anchor(field, value, node.inner_html)
    end

    # Wraps the value's existing markup, never its text: Atlas keeps ownership
    # of how a value reads, so enhanced text (sub/sup) survives the round trip.
    def anchor(field, value, inner_html)
      href = Rails.application.routes.url_helpers.search_catalog_path(f: { field => [value] })
      %(<a href="#{ERB::Util.html_escape(href)}">#{inner_html}</a>)
    end
end
