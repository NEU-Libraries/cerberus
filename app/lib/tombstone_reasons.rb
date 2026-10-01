# frozen_string_literal: true

# The removal notes the library's withdrawal policy allows, in its wording.
#
# Atlas holds the same list and answers 422 `invalid_reason` for anything else,
# so a change here must ship with the matching Atlas change. The notes carry no
# date: the gone page takes it from `tombstoned_at`. See docs/admin.md.
module TombstoneReasons
  ALL = [
    'Removed from view by legal order',
    'Removed from view at request of copyright holder',
    "Removed from view at Northeastern University's discretion",
    "Removed from view at Northeastern University Library's discretion",
    "Removed from view at contributor or content curator's discretion"
  ].freeze

  # Recorded for a depositor or proxy uploader withdrawing their own item. Only
  # the admin tier may choose another note.
  CURATOR = ALL.last

  # The gone page's headline. A withdrawal recorded without a note still reads
  # as a sentence, and an unparseable date drops out rather than guessing.
  def self.sentence(title, reason, tombstoned_at)
    return "\"#{title}\" has been removed." if reason.blank?

    date = removal_date(tombstoned_at)
    note = reason[0].downcase + reason[1..]
    "\"#{title}\" was #{note}#{" on #{date.to_fs(:long)}" if date}."
  end

  def self.removal_date(tombstoned_at)
    return if tombstoned_at.blank?

    Time.zone.parse(tombstoned_at.to_s)&.to_date
  rescue ArgumentError
    nil
  end
end
