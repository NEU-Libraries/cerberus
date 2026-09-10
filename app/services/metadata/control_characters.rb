# frozen_string_literal: true

module Metadata
  # Curator text reduced to what XML 1.0 can actually store. Nokogiri silently
  # DROPS an unstorable character when it serializes, so the two separator
  # controls are MAPPED to whitespace here, never deleted -- deleting runs the
  # words either side of the break together. DEL and the C1 controls
  # (U+007F..U+009F) are legal in XML 1.0 and are left alone; U+0091/U+0092 are
  # a Windows-1252 mojibake signal to report, not to rewrite.
  # See docs/metadata-text.md.
  module ControlCharacters
    # Character classes are built from codepoint lists via `format('\\u%04X', cp)`
    # so this source file stays pure ASCII. A literal control byte on disk is
    # invisible in every editor and diff that would have to review it.
    def self.char_class(codepoints)
      Regexp.new("[#{codepoints.map { |cp| format('\\u%04X', cp) }.join}]")
    end

    # Word's manual line break (Shift+Enter) and page break (Ctrl+Enter).
    SEPARATOR_CODEPOINTS = [0x000B, 0x000C].freeze

    # The rest of C0 -- tab, newline and carriage return are legal and are
    # deliberately absent -- plus the two BMP noncharacters libxml2 rejects.
    DISCARD_CODEPOINTS = ((0x0000..0x0008).to_a + (0x000E..0x001F).to_a + [0xFFFE, 0xFFFF]).freeze

    SEPARATOR_RE = char_class(SEPARATOR_CODEPOINTS).freeze
    DISCARD_RE   = char_class(DISCARD_CODEPOINTS).freeze
    UNSTORABLE_RE = char_class(SEPARATOR_CODEPOINTS + DISCARD_CODEPOINTS).freeze

    DESCRIPTIONS = {
      0x0000 => 'a null',
      0x000B => 'a manual line break, as Word writes Shift+Enter',
      0x000C => 'a page break, as Word writes Ctrl+Enter'
    }.freeze

    class << self
      # For a field that renders on one line. A separator becomes a SPACE, not a
      # newline: these values round-trip through a text input, which cannot hold
      # a newline, so a save the curator meant as a no-op would change the value.
      def clean_line(str)
        clean(str, ' ')
      end

      # For text that may legitimately carry line breaks: an abstract, or a whole
      # raw MODS document. A newline keeps the break the curator made.
      def clean_text(str)
        clean(str, "\n")
      end

      # True when `str` holds a character XML 1.0 cannot store.
      def any?(str)
        UNSTORABLE_RE.match?(str.to_s)
      end

      # A description of what is wrong and where, or nil when the text is clean.
      def report(str)
        found = first_lines(str)
        return nil if found.empty?

        subject = found.one? ? 'a character' : 'characters'
        where = found.map { |cp, line| "#{describe(cp)} on line #{line}" }.join(', ')
        "This document holds #{subject} XML cannot store: #{where}. Replace each one with a line break " \
          'or a space; deleting it runs the words either side of it together.'
      end

      private

        # nil passes straight through: MODSMerge reads a nil field as "leave this
        # alone", where a "" would mean "empty it".
        def clean(str, separator)
          return str if str.nil?

          str.to_s.gsub(SEPARATOR_RE, separator).gsub(DISCARD_RE, '')
        end

        # Each unstorable codepoint present, paired with the 1-based line it first
        # appears on, in reading order. One entry per codepoint, not per
        # occurrence: a paste carries dozens, and listing all of them buries the
        # fix the message is there to give.
        def first_lines(str)
          seen = {}
          str.to_s.each_line.with_index(1) do |line, number|
            line.each_char { |char| seen[char.ord] ||= number if UNSTORABLE_RE.match?(char) }
          end
          seen.sort_by { |codepoint, line| [line, codepoint] }
        end

        def describe(codepoint)
          hex = format('U+%04X', codepoint)
          name = DESCRIPTIONS[codepoint]
          name ? "#{hex} (#{name})" : hex
        end
    end
  end
end
