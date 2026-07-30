# frozen_string_literal: true

# Resolves the Usage Analytics dashboard's optional item-picker + facet
# selections into the noid sets ImpressionsReport needs to narrow every
# metric. The two are combinable (2026-07-30 design call): a facet (Content
# type or Featured Content genre) only ever applies to Works, so when an item
# scope is also active the effective Work set is their intersection — a
# container item's own noid, and any of its descendant containers, fall out
# the moment a facet is active, since neither concept applies to a container.
class ImpressionScope
  # @param item [Hash, nil] { noid:, uuid:, klass:, title: } from the
  #   typeahead picker — klass is 'Work' | 'Collection' | 'Community'.
  # @param facet [Hash, nil] { type:, value: } — type is 'content' | 'featured'.
  def initialize(item: nil, facet: nil)
    @item = item.presence
    @facet = facet.presence
  end

  def active? = item_active? || facet_active?
  def item_active? = @item.present?
  def facet_active? = @facet.present?
  def item_container? = item_active? && @item[:klass].to_s.in?(%w[Collection Community])

  # Top collections only means something for a container-shaped, facet-free
  # scope (or no scope at all — repo-wide) — a facet is Work-only, and a
  # single Work has no sub-collections of its own.
  def show_collections_tab?
    !facet_active? && (!item_active? || item_container?)
  end

  def item_label
    return nil unless item_active?

    "#{@item[:klass]}: #{@item[:title]}"
  end

  def facet_label
    return nil unless facet_active?

    group = @facet[:type] == 'content' ? 'Content' : 'Featured Content'
    "#{group}: #{@facet[:value]}"
  end

  # Exposed so the view can re-select the active facet's <option> — normalized
  # regardless of whether the request arrived via the packed `facet` param or
  # the canonical `facet_type`/`facet_value` pair.
  def facet_type = @facet&.[](:type)
  def facet_value = @facet&.[](:value)

  # Every noid (containers + works) the Overview totals/charts should include.
  # nil means unscoped — the pre-existing repo-wide behavior.
  def overview_noids
    return nil unless active?

    intersect_with_facet(item_all_noids)
  end

  # Work-only noids for Top-files ranking. nil means unscoped.
  def top_works_noids
    return nil unless active?

    intersect_with_facet(item_work_noids)
  end

  # Container-only noids (self + descendant containers) for Top-collections
  # ranking. nil when there's no container item scope — callers only consult
  # this when show_collections_tab? is true, so that's always either
  # "repo-wide" (no item at all) or a real container.
  def top_containers_noids
    return nil unless item_container?

    descendants.container_noids
  end

  private

    def item_all_noids
      return nil unless item_active?

      item_container? ? descendants.noids : [@item[:noid]]
    end

    def item_work_noids
      return nil unless item_active?

      item_container? ? descendants.work_noids : [@item[:noid]]
    end

    def descendants
      @descendants ||= ContainerDescendantsQuery.new(noid: @item[:noid], uuid: @item[:uuid])
    end

    def facet_work_noids
      @facet_work_noids ||= FacetedWorkNoids.call(type: @facet[:type], value: @facet[:value])
    end

    # Intersect an item-derived noid list with the facet's Work noids. Facet
    # alone (no item) => the facet's noids stand alone. Item alone (no facet)
    # => the item noids stand alone (containers included, if any). Both =>
    # their intersection, which naturally drops any container noids since
    # facet_work_noids never contains one.
    def intersect_with_facet(item_noids)
      return facet_work_noids if !item_active? && facet_active?
      return item_noids       if item_active? && !facet_active?

      item_noids & facet_work_noids
    end
end
