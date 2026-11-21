# frozen_string_literal: true

require 'diff/lcs'

# Line diff between two XML documents, for the MODS and Darwin Core history
# pages, with the changed words marked inside a changed line. Returns rows of
# plain text; the view escapes and marks them up. See docs/admin.md.
#
#   MODSDiff.call(from_xml: old_body, to_xml: new_body) # => [MODSDiff::Row, ...]
class MODSDiff < ApplicationService
  Row = Data.define(:kind, :old_number, :new_number, :segments)
  Segment = Data.define(:text, :changed)

  TOKEN = /\s+|\w+|[^\w\s]/
  BLANK = /\A\s+\z/
  # The Dice score two lines need before their words are marked. Scored on
  # words alone: XML is mostly < : = " punctuation, which would make any two
  # elements look alike. 0.6 keeps <mods:nonSort/> and <mods:title/> apart.
  SIMILARITY = 0.6
  # Pairing compares every removed line in a block with every added one, so a
  # wholesale rewrite skips word marks rather than paying for the product.
  PAIRING_LIMIT = 400

  def initialize(from_xml:, to_xml:)
    @from_xml = from_xml
    @to_xml   = to_xml
  end

  def call
    rows = []
    block = []
    Diff::LCS.sdiff(lines(@from_xml), lines(@to_xml)).each do |change|
      if change.action == '='
        rows.concat(changed_block(block))
        block = []
        rows << Row.new(:same, change.old_position + 1, change.new_position + 1,
                        [Segment.new(change.old_element, false)])
      else
        block << change
      end
    end
    rows.concat(changed_block(block))
  end

  private

    def lines(xml)
      canonicalize(xml).split("\n")
    end

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

    # One run of changes between unchanged lines: every removal, then every
    # addition, the order a diff tool prints them in.
    def changed_block(block)
      removed = block.reject { |c| c.action == '+' }.map { |c| [c.old_position + 1, c.old_element] }
      added   = block.reject { |c| c.action == '-' }.map { |c| [c.new_position + 1, c.new_element] }
      marks   = word_marks(removed.map(&:last), added.map(&:last))

      rows_for(:del, removed, marks[:removed]) + rows_for(:ins, added, marks[:added])
    end

    def rows_for(kind, lines, marks)
      lines.each_with_index.map do |(number, text), i|
        numbers = kind == :del ? [number, nil] : [nil, number]
        Row.new(kind, *numbers, marks[i] || plain(text))
      end
    end

    # Pairs each added line with the removed line most like it, rather than the
    # one in the same position, so a block of many removals and one edit still
    # marks the edit.
    def word_marks(removed, added)
      marks = { removed: {}, added: {} }
      return marks if removed.size * added.size > PAIRING_LIMIT

      unpaired = removed.each_index.to_a
      added.each_with_index do |line, a|
        r = closest(removed, unpaired, line) or next
        unpaired.delete(r)
        marks[:removed][r], marks[:added][a] = segments(removed[r], line)
      end
      marks
    end

    def closest(removed, candidates, line)
      candidates.map { |r| [r, similarity(removed[r], line)] }
                .select { |_, score| score >= SIMILARITY }
                .max_by(&:last)&.first
    end

    def similarity(old_line, new_line)
      old_words = old_line.scan(/\w+/)
      new_words = new_line.scan(/\w+/)
      total = old_words.size + new_words.size
      total.zero? ? 0 : (2 * Diff::LCS.lcs(old_words, new_words).size).fdiv(total)
    end

    def segments(old_line, new_line)
      old_parts = []
      new_parts = []
      Diff::LCS.sdiff(old_line.scan(TOKEN), new_line.scan(TOKEN)).each do |change|
        old_parts << [change.old_element, change.action != '='] unless change.action == '+'
        new_parts << [change.new_element, change.action != '='] unless change.action == '-'
      end
      [merge(old_parts), merge(new_parts)]
    end

    # Joins neighbouring tokens into runs, and lets a changed run swallow the
    # whitespace between it and the next one, so a changed phrase reads as one
    # mark rather than a mark per word.
    def merge(parts)
      bridge_blanks(parts)
      parts.chunk_while { |a, b| a[1] == b[1] }
           .map { |run| Segment.new(run.sum('', &:first), run.first[1]) }
    end

    def bridge_blanks(parts)
      parts.each_cons(3) do |before, part, after|
        part[1] = true if before[1] && after[1] && part[0].match?(BLANK)
      end
    end

    def plain(text)
      [Segment.new(text, false)]
    end
end
