# frozen_string_literal: true

# Presentation helpers for the Sets surface. Vocabulary discipline lives
# here: rows are "set aside" / "put back" (never removed/deleted), and copy
# always says the underlying collection is untouched.
module SetsHelper
  # Display label for a recipe noun: the find_many digest title, falling back
  # to the bare noid when the digest is missing (unresolvable / restricted).
  def set_noun_label(noid, recipe_titles)
    recipe_titles[noid]&.[]('title').presence || noid
  end

  # The chip tally: plain total normally; "X of Y" once set-asides have put
  # holes in this collection's contribution (the divergence is the signal).
  def set_chip_count(chip)
    if chip.live < chip.total
      tag.span(class: 'ct has-holes') do
        tag.span(number_with_delimiter(chip.live), class: 'tnum') +
          tag.span(" of #{number_with_delimiter(chip.total)}", class: 'of')
      end
    else
      tag.span(tag.span(number_with_delimiter(chip.total), class: 'tnum'), class: 'ct')
    end
  end

  # The hero's one-line recipe summary, composed from whichever recipe parts
  # are present. Mirrors the mockup's phrasing.
  def set_recipe_sentence(chips_count:, added_count:, aside_count:)
    if chips_count.zero? && added_count.zero?
      return 'This set is empty — add works or collections to it from their pages.'
    end

    clauses = set_recipe_clauses(chips_count, added_count, aside_count)
    sentence = safe_join(['This set contains ', tag.strong(set_recipe_head(chips_count, added_count)),
                          *clauses.flat_map { |clause| [', ', clause] }, '.'])
    sentence += ' It updates automatically as those collections change.' if chips_count.positive?
    sentence
  end

  # Which affordance a picker row gets for this item: :included (already a
  # recipe line), :aside (works only — excluded here, so a re-add would stay
  # invisible), or :addable.
  def set_picker_state(set, kind, noid)
    if kind == 'collection'
      Array(set['included_collections']).include?(noid) ? :included : :addable
    elsif Array(set['included_works']).include?(noid)
      :included
    elsif Array(set['excluded_works']).include?(noid)
      :aside
    else
      :addable
    end
  end

  # Title off a contents/aside Solr document.
  def set_document_title(document)
    Array(document[blacklight_config.index.title_field]).first || document.to_param
  end

  # The provenance badge for a contents row: teal thumbtack for a direct add,
  # navy folder for "via <collection>"; nothing when the edge is untraceable.
  def set_provenance_badge(provenance, recipe_titles)
    case provenance
    when :direct
      tag.span(class: 'prov prov-direct') do
        safe_join([tag.i(nil, class: 'fa-solid fa-thumbtack', 'aria-hidden': 'true'), ' added directly'])
      end
    when String
      tag.span(class: 'prov prov-via') do
        safe_join([tag.i(nil, class: 'fa-solid fa-folder-open', 'aria-hidden': 'true'),
                   " via #{set_noun_label(provenance, recipe_titles)}"])
      end
    end
  end

  private

    def set_recipe_head(chips_count, added_count)
      return "everything in #{pluralize(chips_count, 'collection')}" if chips_count.positive?

      "#{pluralize(added_count, 'item')} you added individually"
    end

    def set_recipe_clauses(chips_count, added_count, aside_count)
      clauses = []
      if chips_count.positive? && added_count.positive?
        clauses << tag.span("plus #{pluralize(added_count, 'item')} you added individually", class: 'pos')
      end
      if aside_count.positive?
        clauses << tag.span("minus #{pluralize(aside_count, 'item')} you set aside", class: 'neg')
      end
      clauses
    end
end
