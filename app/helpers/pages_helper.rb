# frozen_string_literal: true

module PagesHelper
  # The homepage "Featured Content" gateways — the resurrected v1 scholarly
  # category vocabulary (sourced from FeaturedContent::GENRES, shared with
  # showcase provisioning and the deposit fork), plus the Faculty & Staff gateway
  # into the People index. These are curated wayfinding entries (present
  # regardless of current holdings), faithful to v1's Featured Content gateways.

  # [label, icon, href] tuples driving the gateway grid. Each genre gateway
  # resolves to its Featured-Content category landing — the works curated into
  # that category's showcases (FeaturedCategory), not a raw genre-facet browse —
  # via the `category` param. The trailing People gateway resolves to the curated
  # Faculty & Staff directory.
  def featured_gateways
    genre = FeaturedContent::GENRES.map do |label, icon|
      [label, icon, genre_path(category: label)]
    end
    genre << ['Faculty & Staff', 'fa-users', people_path]
  end
end
