# frozen_string_literal: true

# Labels and iconography for a Work's typed associations.
#
# The predicate is Atlas's wire token; the wording is Cerberus's. Each predicate
# reads two ways, because one stored edge is seen from both ends: the Work that
# asserts "is codebook for" is, from the other Work's page, one of its
# "Codebooks". Both phrasings live in one table, as AuditEventsHelper holds its
# action descriptors.
module WorkAssociationsHelper
  # predicate => [outbound phrasing, inbound phrasing, icon].
  #
  # Icons are the restrained Font Awesome solid set the rest of the site uses,
  # chosen for the *kind of thing* the associated Work is. There is deliberately
  # no colour per predicate: a relationship is a label, not a status, and a
  # five-colour legend would outrank the Embargoed and Incomplete pills, which
  # do carry status.
  ASSOCIATION_LABELS = {
    'is_codebook_for'               => ['Is codebook for', 'Codebooks', 'fa-book'],
    'is_figure_for'                 => ['Is figure for', 'Figures', 'fa-chart-simple'],
    'is_instructional_material_for' => ['Is instructional material for', 'Instructional materials',
                                        'fa-chalkboard-user'],
    'is_supplemental_material_for'  => ['Is supplemental material for', 'Supplemental materials', 'fa-paperclip'],
    'is_transcription_of'           => ['Is transcription of', 'Transcriptions', 'fa-file-lines']
  }.freeze

  # The group heading for one predicate in one direction.
  #
  # The fallback matters and is not defensive clutter: Atlas can add a sixth
  # predicate in a release Cerberus has not caught up with, and an unknown token
  # must read as words rather than blow up the page. It humanizes both ways,
  # which is wrong-ish for the inbound phrasing and still better than a crash.
  #
  # @param type [String] the predicate.
  # @param direction [Symbol] :outbound (what this Work asserts) or :inbound.
  def association_label(type, direction)
    entry = ASSOCIATION_LABELS[type.to_s]
    return type.to_s.humanize if entry.nil?

    direction == :inbound ? entry[1] : entry[0]
  end

  # @return [String] the Font Awesome solid class for a predicate.
  def association_icon(type)
    ASSOCIATION_LABELS.dig(type.to_s, 2) || 'fa-link'
  end

  # The sentence under the box's heading, naming which direction the reader is
  # looking at. Kept out of the partial so the two groups differ by data.
  def association_direction_caption(direction)
    if direction == :inbound
      'What other works say about this one'
    else
      'What this work says about others'
    end
  end
end
