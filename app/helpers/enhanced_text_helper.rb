# frozen_string_literal: true

# Renders the <sub> and <sup> markup that descriptive metadata carries as text.
#
# MODS has no element for a subscript, so a chemistry or physics title records
# one by escaping the tags into the title's own text node —
# `Bi&lt;sub&gt;2&lt;/sub&gt;`. Reading that back gives the literal string
# `Bi<sub>2</sub>`, which the view escapes again on output, so a reader sees the
# tags instead of the formula. These helpers close that loop.
#
# Two helpers, because the same string lands in two kinds of place. Use
# `enhanced_text` for element content, where a subscript can actually render.
# Use `plain_text` for an attribute, a page <title>, a citation meta tag, or
# anything about to be truncated — places where markup can only ever show up
# as literal characters, or where a cut could sever a tag.
#
# Both work by pattern, never by parsing the value as HTML. A title is free
# text, and `<` is a character a physics title uses for its own sake: handing
# `Ti <Tc in Bi<sub>2</sub>O` to an HTML parser opens a bogus element at `<Tc`
# that swallows everything up to the next `>`, so the value rendered as `Ti 2O`
# — the span gone and the subscript with it, by an amount that depended on
# where that bracket fell. A record that correctly escapes its less-than as
# `&lt;Tc` produces exactly that text, so well-formed MODS was the trigger.
#
# Atlas's `EnhancedText` is the reference for both algorithms and Atlas's
# decorator renders the MODS block beside these headings, so the two must agree
# character for character. Change them together.
module EnhancedTextHelper
  # The entire allowlist: the two inline tags carrying meaning a reader cannot
  # recover from the plain characters.
  ENHANCED_TAGS = %w[sub sup].freeze

  # The three characters an HTML text node must escape. Deliberately not the
  # quote characters — those matter only inside an attribute value, and this
  # output is always element text, so escaping an apostrophe would show up as
  # `&#39;` in an ordinary possessive title.
  ESCAPES = { '&' => '&amp;', '<' => '&lt;', '>' => '&gt;' }.freeze
  ESCAPE_PATTERN = /[&<>]/

  # An allowlisted tag in its escaped form, and BARE — no attributes. This is
  # what makes the revival safe: the escaped form of a tag carrying anything
  # (`<sub onmouseover=…>`) cannot match, so it can never come back as markup.
  ESCAPED_TAG = %r{&lt;(/?)(#{ENHANCED_TAGS.join('|')})&gt;}i

  # An opening or closing allowlisted tag, attributes and all. Removal tolerates
  # attributes because a page title or an alt attribute must not carry
  # `class="x"` either.
  TAG_PATTERN = %r{</?(?:#{ENHANCED_TAGS.join('|')})\b[^>]*>}i

  # Escape everything, then revive only a bare allowlisted tag. A tag outside
  # the allowlist stays as source text rather than being tidied away: for a
  # repository that is the better failure, because a curator can see the mistake
  # and fix the record, and nothing executes either way.
  def enhanced_text(value)
    value.to_s
         .gsub(ESCAPE_PATTERN, ESCAPES)
         .gsub(ESCAPED_TAG) { "<#{Regexp.last_match(1)}#{Regexp.last_match(2).downcase}>" }
         .html_safe # rubocop:disable Rails/OutputSafety
  end

  # The markup removed, every other character untouched. Returns an ordinary
  # String, not html_safe output, so it composes: the caller can interpolate it
  # into a sentence or hand it to `tag.meta` and let that escape it once.
  #
  # Truncation goes through here too — `truncate` counts characters and knows
  # nothing about tags, so cutting the markup-bearing string can sever one.
  def plain_text(value)
    value.to_s.gsub(TAG_PATTERN, '')
  end
end
