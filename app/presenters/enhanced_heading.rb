# frozen_string_literal: true

# Renders a search-result heading's <sub>/<sup> markup instead of escaping it.
#
# The heading is the one descriptive value Blacklight hands to a view without
# passing it through the field-rendering pipeline's escaping: Rendering::Join
# forwards a single value untouched, and only escapes when it has several to
# join. So a title carrying a subscript arrives here as the raw string, and
# `link_to` escapes it a step later — which is why a formula shows as tags in
# a result list.
#
# Sanitizing here rather than in each component covers every discovery surface
# from one place: the list and gallery result rows, the home page's recent
# items, and Blacklight's own document show page. The character content is
# unchanged for an allowed tag, so the JSON and feed views that read `heading`
# keep emitting exactly what Solr holds.
module EnhancedHeading
  def heading
    view_context.enhanced_text(super)
  end
end
