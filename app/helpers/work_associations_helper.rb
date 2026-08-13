# frozen_string_literal: true

# Labels and iconography for a Work's typed associations.
#
# The predicate is Atlas's wire token; every phrasing is Cerberus's. One stored
# edge reads three ways, so each predicate carries three:
#
#   outbound  a heading on the asserting Work    "Is codebook for"
#   inbound   a heading on the target Work       "Codebooks"
#   assertion the tail of a sentence in the form "codebook for"
#
# They live in one table, as AuditEventsHelper holds its action descriptors, so
# adding a predicate is one entry rather than three edits in three files.
module WorkAssociationsHelper
  # Icons are the restrained Font Awesome solid set the rest of the site uses,
  # chosen for the *kind of thing* the associated Work is. There is deliberately
  # no colour per predicate: a relationship is a label, not a status, and a
  # five-colour legend would outrank the Embargoed and Incomplete pills, which
  # do carry status.
  ASSOCIATION_LABELS = {
    'is_codebook_for'               => {
      outbound: 'Is codebook for', inbound: 'Codebooks',
      assertion: 'codebook for', icon: 'fa-book'
    },
    'is_figure_for'                 => {
      outbound: 'Is figure for', inbound: 'Figures',
      assertion: 'figure for', icon: 'fa-chart-simple'
    },
    'is_instructional_material_for' => {
      outbound: 'Is instructional material for', inbound: 'Instructional materials',
      assertion: 'instructional material for', icon: 'fa-chalkboard-user'
    },
    'is_supplemental_material_for'  => {
      outbound: 'Is supplemental material for', inbound: 'Supplemental materials',
      assertion: 'supplemental material for', icon: 'fa-paperclip'
    },
    'is_transcription_of'           => {
      outbound: 'Is transcription of', inbound: 'Transcriptions',
      assertion: 'transcription of', icon: 'fa-file-lines'
    }
  }.freeze

  # The group heading for one predicate in one direction.
  #
  # The fallback matters and is not defensive clutter: Atlas can add a sixth
  # predicate in a release Cerberus has not caught up with, and an unknown token
  # must read as words rather than raise. It humanizes both ways, which is
  # wrong-ish for the inbound phrasing and still better than a broken page.
  #
  # @param type [String] the predicate.
  # @param direction [Symbol] :outbound (what this Work asserts) or :inbound.
  def association_label(type, direction)
    ASSOCIATION_LABELS.dig(type.to_s, direction) || type.to_s.humanize
  end

  # @return [String] the Font Awesome solid class for a predicate.
  def association_icon(type)
    ASSOCIATION_LABELS.dig(type.to_s, :icon) || 'fa-link'
  end

  # Which direction the reader is looking at, as a heading on the manage panel.
  def association_direction_caption(direction)
    if direction == :inbound
      'What other works say about this one'
    else
      'What this work says about others'
    end
  end

  # Options for the "This work is the …" select on the manage panel.
  #
  # Built from AtlasRb::Work::ASSOCIATION_TYPES rather than from the table
  # above, so the select can only offer a predicate the server accepts. A
  # predicate Atlas ships before Cerberus has a phrase for it appears
  # humanized rather than silently going unofferable.
  def association_type_options
    AtlasRb::Work::ASSOCIATION_TYPES.map do |type|
      [ASSOCIATION_LABELS.dig(type, :assertion) || type.humanize.downcase, type]
    end
  end
end
