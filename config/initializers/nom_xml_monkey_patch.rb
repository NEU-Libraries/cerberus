require 'nom/xml'

# nom-xml re-runs a term's XPath over the whole document every time a node is
# decorated, which is most of the cost of a mods_display render. A Term belongs
# to one terminology, built for one parsed document, and render_mods_display
# only reads that document, so the node set can be cached on the Term.
module Nom
  module XML
    class Term

      def nodes
        @nodes ||= terminology.document.root.xpath(xpath, terminology.namespaces)
      end

    end
  end
end
