# frozen_string_literal: true

# Renders the <sub>/<sup> markup that descriptive metadata carries as escaped
# text. NEVER parse a value as HTML — `<` is free text a physics title uses for
# its own sake, and a parser eats from `<Tc` to the next `>`; match by pattern
# only. Atlas's `EnhancedText` must stay identical. See docs/metadata-text.md.
module EnhancedTextHelper
  ENHANCED_TAGS = %w[sub sup].freeze

  # Element text only: the quote characters are omitted on purpose, or an
  # ordinary possessive title would render as `&#39;`.
  ESCAPES = { '&' => '&amp;', '<' => '&lt;', '>' => '&gt;' }.freeze
  ESCAPE_PATTERN = /[&<>]/

  # BARE tags only — the escaped form of `<sub onmouseover=…>` cannot match, so
  # nothing but a bare allowlisted tag can come back as markup. That is what
  # makes `enhanced_text`'s `html_safe` safe, hence the Rails/OutputSafety off.
  ESCAPED_TAG = %r{&lt;(/?)(#{ENHANCED_TAGS.join('|')})&gt;}i

  TAG_PATTERN = %r{</?(?:#{ENHANCED_TAGS.join('|')})\b[^>]*>}i

  def enhanced_text(value)
    value.to_s
         .gsub(ESCAPE_PATTERN, ESCAPES)
         .gsub(ESCAPED_TAG) { "<#{Regexp.last_match(1)}#{Regexp.last_match(2).downcase}>" }
         .html_safe # rubocop:disable Rails/OutputSafety
  end

  def plain_text(value)
    value.to_s.gsub(TAG_PATTERN, '')
  end
end
