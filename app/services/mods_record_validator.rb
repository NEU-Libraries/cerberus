# frozen_string_literal: true

# XmlValidator's syntax-and-schema floor, plus the fields every DRS record
# must carry: a primary title and, where DescriptivePolicy requires keywords, at
# least one topical subject. Returns an Array; the record is valid iff it is
# empty. See docs/ingest.md.
#
# The field rules run only once the floor passes: they need a parsed document,
# and a schema error is the one the curator has to fix first.
class MODSRecordValidator < ApplicationService
  NO_TITLE    = 'The record has no title. Add a <mods:title> to its <mods:titleInfo>.'
  NO_KEYWORDS = 'The record has no keywords. Add at least one <mods:subject><mods:topic>.'

  def initialize(xml:, keywords:)
    @xml = xml
    @keywords = keywords
  end

  def call
    errors = XmlValidator.call(xml: @xml)
    return errors if errors.any?

    required_field_errors
  end

  private

    # Topical subjects, not just free-text keywords: an authority-bearing
    # subject satisfies the rule, exactly as it does on the metadata form.
    def required_field_errors
      mods = NEU::MODS::Document.parse(@xml)
      errors = []
      errors << NO_TITLE if mods.title_parts[:title].blank?
      errors << NO_KEYWORDS if @keywords && mods.topical_subjects.none?(&:present?)
      errors
    end
end
