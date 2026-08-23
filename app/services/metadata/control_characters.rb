# frozen_string_literal: true

module Metadata
  # Curator text reduced to what XML 1.0 can actually store.
  #
  # XML 1.0's Char production admits tab, newline and carriage return but no other
  # C0 control, and no noncharacter -- not even as a character reference, so there
  # is no encoding that smuggles one through. Nokogiri answers by dropping the
  # character when it serializes a text node, which is worse than a refusal: a
  # manual line break pasted out of Word disappears, the words either side of it
  # run together in the stored MODS and in the search index, and nothing on the
  # screen says so.
  #
  # The two separator controls are therefore MAPPED, not deleted. Word writes a
  # manual line break as U+000B and a page break as U+000C, so each one stands for
  # a boundary the curator can see in the source document; whitespace keeps that
  # boundary where deleting loses it. The rest carry no meaning and are dropped.
  #
  # This is deliberately narrower than NEU::MODS.normalize, which also folds
  # dashes and transliterates smart punctuation. That vocabulary belongs on the
  # access copy the gem projects for display and search. These values are written
  # into the preservation XML, so nothing is touched here beyond what XML has no
  # representation for.
  #
  # DEL and the C1 controls (U+007F..U+009F) are legal in XML 1.0 and are left
  # alone. U+0091/U+0092 are the Windows-1252 mojibake signature: a data-quality
  # signal worth a report, not a character this has any right to rewrite. The
  # gem's access-copy normalizer already keeps them out of display and search.
  module ControlCharacters
    # Character classes are built from codepoint lists via `format('\\u%04X', cp)`
    # so this source file stays pure ASCII. A literal control byte on disk is
    # invisible in every editor and diff that would have to review it.
    def self.char_class(codepoints)
      Regexp.new("[#{codepoints.map { |cp| format('\\u%04X', cp) }.join}]")
    end

    # Word's manual line break (Shift+Enter) and page break (Ctrl+Enter).
    SEPARATOR_CODEPOINTS = [0x000B, 0x000C].freeze

    # What is left once tab, newline, carriage return and the separators above are
    # accounted for: the rest of C0, plus the two noncharacters at the top of the
    # BMP that libxml2 rejects alongside them.
    DISCARD_CODEPOINTS = ((0x0000..0x0008).to_a + (0x000E..0x001F).to_a + [0xFFFE, 0xFFFF]).freeze

    SEPARATOR_RE = char_class(SEPARATOR_CODEPOINTS).freeze
    DISCARD_RE   = char_class(DISCARD_CODEPOINTS).freeze
    UNSTORABLE_RE = char_class(SEPARATOR_CODEPOINTS + DISCARD_CODEPOINTS).freeze

    # Plain-language names for the ones a curator plausibly pastes. Anything else
    # is reported by codepoint alone rather than guessed at.
    DESCRIPTIONS = {
      0x0000 => 'a null',
      0x000B => 'a manual line break, as Word writes Shift+Enter',
      0x000C => 'a page break, as Word writes Ctrl+Enter'
    }.freeze

    class << self
      # For a field that renders on one line: a title, a title part, a keyword, a
      # name. A separator becomes a space rather than a newline because these
      # values round-trip through a text input, which cannot hold a newline --
      # pre-filling the edit form with one and saving would change the stored
      # value a second time, silently, on a save the curator meant as a no-op.
      def clean_line(str)
        clean(str, ' ')
      end

      # For text that may legitimately carry line breaks: an abstract, or a whole
      # raw MODS document. A newline keeps the break the curator made, and the
      # gem's access-copy projection folds it back to a space for display and
      # search, so nothing downstream has to know it is there.
      def clean_text(str)
        clean(str, "\n")
      end

      # True when `str` holds a character XML 1.0 cannot store.
      def any?(str)
        UNSTORABLE_RE.match?(str.to_s)
      end

      # A description of what is wrong and where, or nil when the text is clean.
      # Written for the curator reading a validation panel: libxml answers the
      # same input with "PCDATA invalid Char value 11", which names neither the
      # character, nor where it came from, nor what to do about it.
      def report(str)
        found = first_lines(str)
        return nil if found.empty?

        subject = found.one? ? 'a character' : 'characters'
        where = found.map { |cp, line| "#{describe(cp)} on line #{line}" }.join(', ')
        "This document holds #{subject} XML cannot store: #{where}. Replace each one with a line break " \
          'or a space; deleting it runs the words either side of it together.'
      end

      private

        # nil passes straight through, because MODSMerge reads a nil field as
        # "leave this alone" and a "" would mean "empty it".
        def clean(str, separator)
          return str if str.nil?

          str.to_s.gsub(SEPARATOR_RE, separator).gsub(DISCARD_RE, '')
        end

        # Each unstorable codepoint present, paired with the 1-based line it first
        # appears on, in reading order. One entry per codepoint rather than per
        # occurrence: a paste carries dozens, and listing every one buries the fix
        # the message is there to give.
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
