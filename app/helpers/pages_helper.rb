# frozen_string_literal: true

module PagesHelper
  # The homepage "Featured Content" gateways — the resurrected v1 scholarly
  # category vocabulary, each a canned link into the catalog's genre facet, plus
  # the Faculty & Staff gateway into the People index. These are curated
  # wayfinding entries (present regardless of current holdings), faithful to v1's
  # Featured Content gateways. Each genre link drills into `genre_ssim`; the
  # People gateway is its sibling, the global Faculty & Staff directory.
  FEATURED_GENRES = [
    ['Research Publications',   'fa-file-lines'],
    ['Presentations',           'fa-person-chalkboard'],
    ['Datasets',                'fa-database'],
    ['Technical Reports',       'fa-file-contract'],
    ['Monographs',              'fa-book'],
    ['Theses & Dissertations',  'fa-graduation-cap'],
    ['Other Publications',      'fa-newspaper']
  ].freeze

  # [label, icon, href] tuples driving the gateway grid. Genre gateways resolve
  # to a single-value genre facet selection; the trailing People gateway resolves
  # to the curated Faculty & Staff directory.
  def featured_gateways
    genre = FEATURED_GENRES.map do |label, icon|
      [label, icon, search_catalog_path(f: { genre_ssim: [label] })]
    end
    genre << ['Faculty & Staff', 'fa-users', people_path]
  end
end
