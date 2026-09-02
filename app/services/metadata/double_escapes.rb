# frozen_string_literal: true

module Metadata
  # An entity reference escaped a second time on its way into storage:
  # `&amp;lt;` in the source is the escaped form of the TEXT `&lt;`, so a reader
  # is shown the escape rather than the `<` the record means. The document stays
  # well-formed, which is why nothing else catches it. See docs/metadata-text.md.
  module DoubleEscapes
    # ONLY the five entities XML 1.0 predefines. Adding `nbsp` here would decode
    # `&amp;nbsp;` to `&nbsp;`, which XML cannot parse, turning a valid document
    # into one that no longer loads.
    CHARACTERS = { 'lt' => '<', 'gt' => '>', 'amp' => '&', 'quot' => '"', 'apos' => "'" }.freeze

    NESTED_RE = /&amp;(#{CHARACTERS.keys.join('|')});/

    class << self
      # True when the source holds a reference at the wrong depth.
      def any?(xml)
        NESTED_RE.match?(xml.to_s)
      end

      # One level off every nested reference, and nothing else touched. One
      # level, not all of them: a document three deep is worth a second look, so
      # the advisory returns while any depth remains and the curator presses
      # again.
      def decode(xml)
        return xml if xml.nil?

        xml.to_s.gsub(NESTED_RE) { "&#{Regexp.last_match(1)};" }
      end

      # What is wrong, where, and what the reader sees instead -- or nil when the
      # document is clean.
      def report(xml)
        found = first_lines(xml)
        return nil if found.empty?

        first_name, = found.first
        subject = found.one? ? 'a character' : 'characters'
        where = found.map { |name, line| "&amp;#{name}; on line #{line}" }.join(', ')
        "This document escapes #{subject} twice: #{where}. #{consequence(first_name)} " \
          'The XML is valid, so Save takes it as it stands.'
      end

      private

        def consequence(name)
          "A reader sees &#{name}; where the record means #{CHARACTERS[name]}."
        end

        # Each nested reference present, paired with the 1-based line it first
        # appears on, one entry per reference. Reading order comes from the
        # Hash's insertion order; SORTING the pairs would order the message by
        # entity name instead, sending the curator up and down the buffer.
        def first_lines(xml)
          seen = {}
          xml.to_s.each_line.with_index(1) do |line, number|
            line.scan(NESTED_RE) { |name,| seen[name] ||= number }
          end
          seen.to_a
        end
    end
  end
end
