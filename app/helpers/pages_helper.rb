# frozen_string_literal: true

module PagesHelper
  # The homepage "Featured Content" gateways — the resurrected v1 scholarly
  # category vocabulary (sourced from FeaturedContent::GENRES, shared with
  # showcase provisioning and the deposit fork), plus the Faculty & Staff gateway
  # into the People index and the Communities gateway into the communities index.
  # These are curated wayfinding entries (present regardless of current
  # holdings), faithful to v1's Featured Content gateways.

  # [label, icon, href] tuples driving the gateway grid. Each genre gateway
  # resolves to its Featured-Content category landing — the works curated into
  # that category's showcases (FeaturedCategory), not a raw genre-facet browse —
  # via the `category` param. The People gateway resolves to the curated
  # Faculty & Staff directory. Nine entries make three even rows of three, and
  # the view lays the grid out for that count. Each icon matches the page it
  # opens: one person for Faculty & Staff, a group for Communities, as in v1.
  def featured_gateways
    genre = FeaturedContent::GENRES.map do |label, icon|
      [label, icon, genre_path(category: label)]
    end
    genre << ['Faculty & Staff', 'fa-user', people_path]
    genre << ['Communities', 'fa-users', communities_path]
  end
end
