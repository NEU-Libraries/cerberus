# frozen_string_literal: true

# The vocabulary for Atlas's `incomplete_reason`, and what each token reads as.
#
# Atlas stores the token opaquely and does not validate it, so this list is the
# only definition of it — which is deliberate: a new token ships with the job
# that raises it, without an Atlas release.
#
# Each entry says what the reader has LOST, not which job failed. "No PDF
# version was made" is something a person can act on; "PdfRenditionJob gave up"
# is not. The token keeps the cause greppable in the log and groupable in a list.
#
# UNKNOWN is the fallback, matching AuditEventsHelper's generic descriptor: a
# token this map has not been taught about still renders sensibly, so adding one
# in a job needs no view change and can never blank a page.
module IncompleteReasons
  PDF_RENDITION = 'pdf_rendition_gave_up'
  MEDIA_RENDITION = 'media_rendition_gave_up'
  DERIVATIVES = 'derivatives_gave_up'
  FULL_TEXT = 'full_text_gave_up'
  THUMBNAILS = 'thumbnails_gave_up'

  DESCRIPTIONS = {
    PDF_RENDITION   => 'No PDF version was made, so this document has no preview.',
    MEDIA_RENDITION => 'No streamable version was made, so this file may not play in the browser.',
    DERIVATIVES     => 'The small, medium and large download sizes were not made.',
    FULL_TEXT       => 'The text was not extracted, so this work will not be found by a full-text search.',
    THUMBNAILS      => 'No thumbnail was made, so this work shows a placeholder icon.'
  }.freeze

  UNKNOWN = 'Part of this work was not finished. Contact DRS staff.'

  def self.describe(token)
    DESCRIPTIONS.fetch(token.to_s, UNKNOWN)
  end
end
