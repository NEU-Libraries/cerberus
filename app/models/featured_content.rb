# frozen_string_literal: true

# Single source of truth for the resurrected v1 scholarly category vocabulary.
# Three surfaces draw from this one list: the genre "showcase" Collections a
# Community is provisioned with on creation (CommunitiesController#create), the
# homepage Featured Content gateways (PagesHelper#featured_gateways), and the
# publish branch of the weighted deposit fork (WorksController). Keeping the
# vocab here — not in a view helper — lets controllers reach it without pulling
# in helper context. Each entry is [label, font-awesome icon].
class FeaturedContent
  GENRES = [
    ['Research Publications',  'fa-file-lines'],
    ['Presentations',          'fa-person-chalkboard'],
    ['Datasets',               'fa-database'],
    ['Technical Reports',      'fa-file-contract'],
    ['Monographs',             'fa-book'],
    ['Theses & Dissertations', 'fa-graduation-cap'],
    ['Other Publications',     'fa-newspaper']
  ].freeze

  # Just the showcase titles / publish categories (no icons) — what
  # provisioning and showcase discovery match on.
  def self.genre_labels
    GENRES.map(&:first)
  end
end
