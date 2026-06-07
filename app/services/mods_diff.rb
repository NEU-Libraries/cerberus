# frozen_string_literal: true

require 'diffy'

# Line-based diff between two MODS XML documents, for the MODS version-history
# page. Each document is first canonicalised through Nokogiri (pretty-printed,
# blank text nodes stripped) so the diff reflects *content* changes, not
# serialisation whitespace from however the XML was stored. Diffing is
# Cerberus's job — Atlas stores the versions, Cerberus presents the comparison
# (the layering principle: Atlas = persistence, Cerberus = workflow/parsing).
#
#   diff = ModsDiff.call(from_xml: old_body, to_xml: new_body) # => Diffy::Diff
#   diff.to_s(:html)   # rendered side in the view
class ModsDiff < ApplicationService
  def initialize(from_xml:, to_xml:)
    @from_xml = from_xml
    @to_xml   = to_xml
  end

  def call
    Diffy::Diff.new(
      canonicalize(@from_xml),
      canonicalize(@to_xml),
      include_plus_and_minus_in_html: true
    )
  end

  private

    # Pretty-print so each line is content-meaningful; fall back to the raw
    # string if the body won't parse — a read-only diff view must never blow up
    # on a historically malformed document.
    def canonicalize(xml)
      doc = Nokogiri::XML(xml.to_s, &:noblanks)
      return xml.to_s if doc.root.nil?

      doc.to_xml(indent: 2)
    rescue StandardError
      xml.to_s
    end
end
