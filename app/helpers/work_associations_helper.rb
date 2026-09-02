# frozen_string_literal: true

# Labels and iconography for a Work's typed associations. Each predicate
# carries three phrasings — outbound, inbound and assertion — in one table, so
# adding one is a single entry. See docs/edit-surfaces.md.
module WorkAssociationsHelper
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

  # The fallback is not defensive clutter: Atlas can ship a sixth predicate
  # before Cerberus has a phrase for it, and an unknown token must read as
  # words rather than raise. Humanizing reads wrong-ish inbound, not broken.
  def association_label(type, direction)
    ASSOCIATION_LABELS.dig(type.to_s, direction) || type.to_s.humanize
  end

  def association_icon(type)
    ASSOCIATION_LABELS.dig(type.to_s, :icon) || 'fa-link'
  end

  def association_direction_caption(direction)
    if direction == :inbound
      'What other works say about this one'
    else
      'What this work says about others'
    end
  end

  # Built from AtlasRb::Work::ASSOCIATION_TYPES, not the table above, so the
  # select can only offer a predicate the server accepts.
  def association_type_options
    AtlasRb::Work::ASSOCIATION_TYPES.map do |type|
      [ASSOCIATION_LABELS.dig(type, :assertion) || type.humanize.downcase, type]
    end
  end
end
