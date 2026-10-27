# frozen_string_literal: true

class CriticalCss
  # The tokens a selector needs on the page before it can match anything. A
  # token is a tag name, `.class`, `#id` or `[attribute`, the same spelling
  # Markup.tokens uses for the page.
  #
  # Every simplification here may only ever drop a requirement, never add one:
  # an extra rule costs bytes, but a missing one makes the page shift when the
  # full stylesheet lands.
  module Selector
    FUNCTIONAL_PSEUDO = /::?[\w-]+\(/
    ATTRIBUTE = /\[\s*([^\s~|^$*=\]]+)[^\]]*\]/
    # A hex escape swallows the one space that ends it: `.\31 0` is the class `10`.
    CLASS_OR_ID = /([.#])((?:[\w-]|\\\h{1,6}\s?|\\.)+)/
    PSEUDO = /::?[\w-]+/
    TYPE = /(?:\A|[\s>+~])([a-zA-Z][\w-]*)/

    module_function

    def needs(selector_list)
      split_list(selector_list).map { |selector| tokens(selector) }
    end

    # Arguments of :not(), :is(), :where(), :has() and :nth-*() are dropped
    # whole, so `.a:not(.b)` needs only `.a`.
    def tokens(selector)
      rest = drop_functional_pseudos(selector)
      attributes = rest.scan(ATTRIBUTE).map { |(name)| "[#{name.downcase}" }
      rest = rest.gsub(ATTRIBUTE, ' ')
      names = rest.scan(CLASS_OR_ID).map { |sigil, name| sigil + unescape(name) }
      types = rest.gsub(CLASS_OR_ID, ' ').gsub(PSEUDO, ' ').scan(TYPE).map { |(type)| type.downcase }
      (attributes + names + types).uniq
    end

    def split_list(selector_list)
      parts = []
      depth = 0
      current = +''
      selector_list.each_char do |char|
        depth += 1 if '(['.include?(char)
        depth -= 1 if ')]'.include?(char)
        next current << char unless char == ',' && depth.zero?

        parts << current
        current = +''
      end
      parts << current
    end

    def drop_functional_pseudos(selector)
      out = selector.dup
      while (match = FUNCTIONAL_PSEUDO.match(out))
        close = closing_paren(out, match.end(0))
        out[match.begin(0)..close] = ' '
      end
      out
    end

    def closing_paren(text, from)
      depth = 1
      (from...text.length).each do |i|
        depth += 1 if text[i] == '('
        depth -= 1 if text[i] == ')'
        return i if depth.zero?
      end
      text.length - 1
    end

    # `.\31 0` and `.sm\:flex` are escaped class names; the page spells them `10`
    # and `sm:flex`.
    def unescape(name)
      name.gsub(/\\([0-9a-fA-F]{1,6})\s?/) { ::Regexp.last_match(1).hex.chr(Encoding::UTF_8) }
          .gsub(/\\(.)/, '\1')
    end
  end
end
