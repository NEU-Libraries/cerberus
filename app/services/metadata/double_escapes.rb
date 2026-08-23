# frozen_string_literal: true

module Metadata
  # An entity reference that was escaped a second time on its way into storage.
  #
  # `&amp;lt;` in the source is the escaped form of the TEXT `&lt;`, so the reader
  # is shown the escape rather than the `<` the record means. The document is
  # perfectly well-formed, which is why nothing else catches it: only a human can
  # see that the record meant a character and stored its spelling instead.
  #
  # It arrives from a display pipeline that wrote text into HTML unescaped, where
  # escaping twice was the only way to make a `<` visible. A record can hold both
  # depths at once -- a title escaped once, an abstract escaped twice -- so the
  # record's own correct fields are the reference for what the rest should hold.
  #
  # ONLY the five entities XML predefines are recognised. Decoding `&amp;nbsp;`
  # would produce `&nbsp;`, which XML cannot parse, turning a valid document into
  # one that no longer loads; a numeric reference cannot appear at this depth,
  # because the pipeline that produced these deleted numeric references outright.
  #
  # Detection and repair both work on the raw source, not on parsed nodes, so a
  # reference inside a comment or an attribute is treated the same as one in an
  # element. The curator reads the result in the editor before saving it, which is
  # what makes that breadth safe.
  module DoubleEscapes
    # The named entities XML 1.0 predefines, mapped to the character each one
    # stands for -- the character the reader should have been shown.
    CHARACTERS = { 'lt' => '<', 'gt' => '>', 'amp' => '&', 'quot' => '"', 'apos' => "'" }.freeze

    NESTED_RE = /&amp;(#{CHARACTERS.keys.join('|')});/

    class << self
      # True when the source holds a reference at the wrong depth.
      def any?(xml)
        NESTED_RE.match?(xml.to_s)
      end

      # One level off every nested reference, and nothing else touched.
      #
      # One level, not all of them: one level is the defect, and a document three
      # deep is rare enough to be worth a second look. The advisory returns after
      # a repair while any depth remains, so pressing again is the way through.
      def decode(xml)
        return xml if xml.nil?

        xml.to_s.gsub(NESTED_RE) { "&#{Regexp.last_match(1)};" }
      end

      # What is wrong, where, and what the reader sees instead -- or nil when the
      # document is clean. Written for a curator reading an advisory: the XML is
      # valid, so this is the only place the problem can be named at all.
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

        # A reader sees the escape itself, spelled out with the first finding so
        # the sentence names real characters rather than describing a class of
        # them. "&lt; where the record means <" is the whole problem in six words.
        def consequence(name)
          "A reader sees &#{name}; where the record means #{CHARACTERS[name]}."
        end

        # Each nested reference present, paired with the 1-based line it first
        # appears on. One entry per reference rather than per occurrence: a
        # migrated abstract carries the same one in every paragraph, and listing
        # every hit buries the fix the message exists to give.
        #
        # Reading order comes from the insertion order of the Hash, which is the
        # order the scan meets them. Sorting the pairs would order the message by
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
