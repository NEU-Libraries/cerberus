# frozen_string_literal: true

module Cerberus
  # The facet sidebar wrapper, without Bootstrap's accordion class.
  #
  # Blacklight puts `accordion` on the panel container so its facet panels
  # behave as one accordion. Ours are cards (see the
  # Blacklight::Facets::FieldComponent template override), and the class on the
  # container would apply accordion spacing and border-collapsing rules to
  # them. Everything else keeps Blacklight's defaults.
  class FacetGroupComponent < Blacklight::Response::FacetGroupComponent
    def initialize(body_classes: 'facets-collapse d-lg-block collapse', **kwargs)
      super
    end
  end
end
