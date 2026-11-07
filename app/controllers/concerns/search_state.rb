# frozen_string_literal: true

class SearchState < Blacklight::SearchState
  include Rails.application.routes.url_helpers

  def url_for_document(doc, options = {})
    # A synthetic navigation row (e.g. a community's "Faculty & Staff" entry)
    # carries its own destination — it has no per-type show route.
    return doc.nav_url if doc.respond_to?(:nav_url) && doc.nav_url.present?

    if doc.respond_to?(:klass) && doc.klass.present?
      # Need to handle collection/system_collection difference
      model_str = ActiveModel::Naming.singular_route_key(doc.klass)
      return send("#{model_str}_path", doc)
    end

    super
  end

  # A controller may name the default for a request with no sort (see
  # TitleBrowseSort). Chosen here rather than written into params, it stays out
  # of the links and forms built from this state, so a search typed after
  # clicking a facet still ranks by relevance.
  def sort_field
    return super if sort_field_key.present? || !controller.respond_to?(:browse_sort_key, true)

    blacklight_config.sort_fields[controller.send(:browse_sort_key, self)] || super
  end
end
