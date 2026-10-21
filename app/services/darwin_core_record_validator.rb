# frozen_string_literal: true

# XmlValidator's syntax-and-schema floor, plus the shape a Work's Darwin Core
# record must have: a dwr:SimpleDarwinRecordSet root holding exactly one
# dwr:SimpleDarwinRecord. Returns an Array; the record is valid iff it is empty.
# See docs/ingest.md.
#
# Atlas refuses the same shapes with a 422, but the loader must refuse a row
# before it creates the row's Work, so the check runs here first.
class DarwinCoreRecordValidator < ApplicationService
  RECORD_SET_NS = 'http://rs.tdwg.org/dwc/xsd/simpledarwincore/'

  NOT_A_RECORD_SET = 'The root element must be a <dwr:SimpleDarwinRecordSet>.'

  def self.record_count_error(count)
    "A work holds one <dwr:SimpleDarwinRecord>; this file has #{count}."
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

      count = root.element_children.count { |child| record_set_element?(child, 'SimpleDarwinRecord') }
      count == 1 ? [] : [self.class.record_count_error(count)]
    end

    def record_set_element?(node, name)
      node.present? && node.name == name && node.namespace&.href == RECORD_SET_NS
    end
end
