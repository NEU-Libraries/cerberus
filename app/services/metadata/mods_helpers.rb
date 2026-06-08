# frozen_string_literal: true

module Metadata
  # Shared MODS-document helpers for the structure-safe simple-form read
  # (MODSFields) and write (MODSMerge) paths. Centralising them here means the
  # reader and writer agree on exactly what the simple form owns:
  #
  #   * the PRIMARY title (top-level `titleInfo[@usage='primary']`) -- never the
  #     title nested in a `relatedItem`,
  #   * the first top-level `<abstract>`,
  #   * "keyword" subjects: bare `<subject>` (no attributes) whose children are
  #     all `<topic>`. Authority/valueURI-bearing subjects, name subjects, and
  #     anything else are curated metadata the simple form must preserve.
  module MODSHelpers
    MODS = { 'mods' => 'http://www.loc.gov/mods/v3' }.freeze
    NBSP = [0xA0].pack('U') # U+00A0 non-breaking space, built from codepoint

    private

      # Top-level primary titleInfo (falls back to the first top-level titleInfo).
      # Scoped to direct children of <mods:mods> so a relatedItem's nested
      # titleInfo is never matched.
      def primary_title_info(doc)
        doc.at_xpath("/mods:mods/mods:titleInfo[@usage='primary']", MODS) ||
          doc.at_xpath('/mods:mods/mods:titleInfo', MODS)
      end

      # The bare keyword subjects the simple form manages: attribute-free
      # <subject> elements whose element children are all <topic>. Anything with
      # an authority/valueURI (or a non-topic child, e.g. a <name> subject) is
      # curated and left untouched.
      def keyword_subjects(doc)
        doc.xpath('/mods:mods/mods:subject', MODS).select { |s| keyword_subject?(s) }
      end

      def keyword_subject?(subject)
        return false if subject.attributes.any?

        topics = subject.element_children
        topics.any? && topics.all? { |c| c.name == 'topic' }
      end

      # Build a namespaced MODS element reusing the document's existing `mods:`
      # namespace declaration (so we never re-declare xmlns on new nodes).
      def build_mods_node(doc, name, text = nil)
        node = Nokogiri::XML::Node.new(name, doc)
        node.namespace = doc.root.namespace_definitions.find { |d| d.prefix == 'mods' }
        node.content = text unless text.nil?
        node
      end

      # Change-detection guard: treat values differing only by insignificant
      # whitespace (NBSP vs space, collapsible runs, leading/trailing) as equal,
      # so a form round-trip that normalises NBSP->space is not mistaken for an
      # edit (which would mint a needless OCFL MODS version). Mirrors the guard
      # that previously lived in Atlas's MODSAssignment.
      def whitespace_equivalent?(current, incoming)
        normalize_ws(current) == normalize_ws(incoming)
      end

      def normalize_ws(str)
        # \s doesn't match U+00A0 (NBSP) in Ruby's default mode, so fold NBSP to a
        # plain space first, then collapse any whitespace run to one space.
        str.to_s.tr(NBSP, ' ').gsub(/\s+/, ' ').strip
      end
  end
end
