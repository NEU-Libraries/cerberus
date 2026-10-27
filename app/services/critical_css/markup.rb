# frozen_string_literal: true

class CriticalCss
  # The tokens a rendered page carries, spelled the way Selector spells a
  # selector's needs: tag names, `.class`, `#id` and `[attribute`.
  #
  # It scans the raw HTML rather than a parsed tree, so markup inside a
  # <template> or a script string counts too. Stimulus clones those templates
  # into the page, and over-counting only costs bytes.
  module Markup
    TAG = %r{<([a-zA-Z][\w:-]*)((?:\s+[^\s"'>/=]+(?:\s*=\s*(?:"[^"]*"|'[^']*'|[^\s"'=<>`]+))?)*)\s*/?>}
    ATTRIBUTE = %r{([^\s"'>/=]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+)))?}

    module_function

    def tokens(html)
      found = Set.new
      html.scan(TAG) do |name, attributes|
        found << name.downcase
        attributes.scan(ATTRIBUTE) { |attr, *value| add_attribute(found, attr.downcase, value.compact.first) }
      end
      found
    end

    def add_attribute(found, name, value)
      found << "[#{name}"
      case name
      when 'class' then value.to_s.split.each { |klass| found << ".#{CGI.unescapeHTML(klass)}" }
      when 'id' then found << "##{CGI.unescapeHTML(value.to_s)}"
      end
    end
  end
end
