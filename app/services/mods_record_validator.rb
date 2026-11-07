# frozen_string_literal: true

# XmlValidator's syntax-and-schema floor, plus the fields every DRS record
# must carry: a primary title and, where DescriptivePolicy requires keywords, at
# least one subject. Returns an Array; the record is valid iff it is empty. See
# docs/ingest.md.
#
# The field rules run only once the floor passes: they need a parsed document,
# and a schema error is the one the curator has to fix first.
class MODSRecordValidator < ApplicationService
  NO_TITLE    = 'The record has no title. Add a <mods:title> to its <mods:titleInfo>.'
  NO_SUBJECTS = 'The record has no subjects. Add at least one <mods:subject>.'

  def initialize(xml:, keywords:)
    @xml = xml
    @keywords = keywords
  end

  def call
    errors = XmlValidator.call(xml: @xml, namespace: 'xmlns:mods')
    return errors if errors.any?

    required_field_errors
  end

  private

    # Any subject heading counts, of any kind, exactly as on the metadata form.
    # A subject holding only a geographic code or coordinates has no heading
    # text, so it does not.
    def required_field_errors
      mods = NEU::MODS::Document.parse(@xml)
      errors = []
      errors << NO_TITLE if mods.title_parts[:title].blank?
      errors << NO_SUBJECTS if @keywords && mods.subject_headings.empty?
      errors
    end
end
