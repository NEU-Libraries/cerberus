# frozen_string_literal: true

# XmlValidator's syntax-and-schema floor, plus the shape a Work's Darwin Core
# record must have: a dwr:SimpleDarwinRecordSet root holding exactly one
# dwr:SimpleDarwinRecord, with no term twice. Returns an Array; the record is
# valid iff it is empty. See docs/ingest.md.
#
# Atlas refuses the same shapes with a 422, but the loader must refuse a row
# before it creates the row's Work, so the check runs here first.
class DarwinCoreRecordValidator < ApplicationService
  RECORD_SET_NS = 'http://rs.tdwg.org/dwc/xsd/simpledarwincore/'

  # Atlas keys its access copy by a term's bare name across these, so
  # dc:type and dcterms:type collide there although the schema allows both.
  TERM_NAMESPACES = %w[
    http://rs.tdwg.org/dwc/terms/
    http://purl.org/dc/elements/1.1/
    http://purl.org/dc/terms/
  ].freeze

  NOT_A_RECORD_SET = 'The root element must be a <dwr:SimpleDarwinRecordSet>.'

  def self.record_count_error(count)
    "A work holds one <dwr:SimpleDarwinRecord>; this file has #{count}."
  end

  def self.duplicate_term_error(term)
    "The term #{term} appears more than once. Keep one, and remove the other."
  end

  def initialize(xml:)
    @xml = xml
  end

  def call
    errors = XmlValidator.call(xml: @xml, namespace: nil)
    return errors if errors.any?

    shape_errors
  end

  private

    # By namespace URI, never by prefix, as Atlas checks it: a document may
    # bind the record-set namespace to any prefix, or make it the default.
    def shape_errors
      root = Nokogiri::XML(@xml).root
      return [NOT_A_RECORD_SET] unless record_set_element?(root, 'SimpleDarwinRecordSet')

      records = root.element_children.select { |child| record_set_element?(child, 'SimpleDarwinRecord') }
      return [self.class.record_count_error(records.size)] unless records.one?

      duplicate_term_errors(records.first)
    end

    # Blank terms are skipped, as Atlas drops them before it compares.
    def duplicate_term_errors(record)
      terms = record.element_children.select do |element|
        TERM_NAMESPACES.include?(element.namespace&.href) && element.text.strip.present?
      end
      terms.map(&:name).tally.select { |_, count| count > 1 }.keys.map { |term| self.class.duplicate_term_error(term) }
    end

    def record_set_element?(node, name)
      node.present? && node.name == name && node.namespace&.href == RECORD_SET_NS
    end
end
