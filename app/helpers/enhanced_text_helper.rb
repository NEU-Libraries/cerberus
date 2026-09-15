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

  # One or more blank lines, tolerating the trailing spaces a textarea collects.
  PARAGRAPH_BREAK = /\n[ \t]*(?:\n[ \t]*)+/

  def enhanced_text(value)
    value.to_s
         .gsub(ESCAPE_PATTERN, ESCAPES)
         .gsub(ESCAPED_TAG) { "<#{Regexp.last_match(1)}#{Regexp.last_match(2).downcase}>" }
         .html_safe
  end

  def plain_text(value)
    value.to_s.gsub(TAG_PATTERN, '')
  end

  # An abstract as the paragraphs its author typed. A blank line starts a new
  # paragraph; a lone newline is a wrap, not a break, and becomes a space.
  #
  # Those two rules are ATLAS'S, not a choice made here: its decorator projects
  # the same abstract into <p> elements that way, so a Work's show page and a
  # container's have to agree about one stored value. Verified against Atlas on
  # "a\nb\n\nc" -> "<p>a b</p><p>c</p>".
  #
  # Each paragraph still goes through enhanced_text, so the no-HTML-parsing rule
  # in this file's header holds — the <p> wrappers are built here, never taken
  # from the value.
  def enhanced_paragraphs(value)
    paragraphs = value.to_s.split(PARAGRAPH_BREAK).filter_map do |para|
      collapsed = para.gsub(/\s*\n\s*/, ' ').strip
      content_tag(:p, enhanced_text(collapsed)) if collapsed.present?
    end
    safe_join(paragraphs)
  end
end
