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
module EnhancedTextHelper
  # The entire allowlist: the two inline tags carrying meaning a reader cannot
  # recover from the plain characters. Attributes are refused outright, so there
  # is nothing for a style, an event handler, or a URL to ride in on — the value
  # comes from a curator-editable MODS field, which is untrusted input.
  ENHANCED_TAGS = %w[sub sup].freeze

  def enhanced_text(value)
    sanitize(value.to_s, tags: ENHANCED_TAGS, attributes: [])
  end

  # Markup removed rather than escaped. An attribute or a <title> shows a
  # stray `<sub>` as characters, which is worse than dropping it. Truncation
  # goes through here too: `truncate` counts characters and knows nothing
  # about tags, so cutting the markup-bearing string can sever one.
  #
  # Returns an ordinary String, not html_safe output, so it composes: the caller
  # can interpolate it into a sentence or hand it to `tag.meta` and let that
  # escape it once. `strip_tags` would be the obvious tool but returns escaped
  # html_safe *output* — interpolating that into a larger string escapes it a
  # second time and prints `&amp;amp;` for an ampersand.
  def plain_text(value)
    Nokogiri::HTML5.fragment(value.to_s).text
  end
end
