# frozen_string_literal: true

module Admin
  # The daily digest's count block.
  #
  # Every figure that has something behind it links to the surface that lists
  # what it counted, so the block is a way into the day rather than a readout.
  # A zero carries no link: there is nothing there to open, and a link to an
  # empty list wastes the click.
  #
  # Split from LedgerHelper because the two speak different vocabularies — that
  # one formats a row, this one assembles a summary — and because a view that
  # builds ten route helpers inline stops being a template.
  module DigestHelper
    # @return [Array(String, String, nil)] the text, and a path or nil.
    def digest_figure(count, label, path)
      [[count.to_i, label].join(' '), (path if count.to_i.positive?)]
    end

    # The block in reading order: { label => [figure, ...] }.
    #
    # Every figure counted one day, so every link carries that day. Without it
    # "1 made" on August 3rd opened every request ever made, which answers a
    # question nobody asked. The deposit figures are the exception and take no
    # day — see deposit_figures.
    def digest_figures(counts, showcases, day)
      { 'Requests'   => [digest_figure(counts['requests_made'], 'made',
                                       admin_ledger_path(tab: 'requests', on: day))],
        'Loads'      => load_figures(counts, day),
        'Deposits'   => deposit_figures(counts),
        'Repository' => repository_figures(counts, day),
        'Showcases'  => showcase_figures(showcases, day) }
    end

    private

      def load_figures(counts, day)
        path = admin_ledger_path(tab: 'activity', kind: 'load_report', on: day)
        [digest_figure(counts['loads_run'], 'run', path),
         digest_figure(counts['loads_failed'], 'failed', path)]
      end

      # These two point at the triage lists rather than the ledger, and carry no
      # day: they are a live backlog, not a figure for the day being summed up,
      # so the place to act on them is the surface that works them, as it is now.
      def deposit_figures(counts)
        [digest_figure(counts['deposits_unconfirmed'], 'waiting on a depositor',
                       admin_deposit_triage_path(state: 'unconfirmed')),
         digest_figure(counts['deposits_incomplete'], 'missing something',
                       admin_deposit_triage_path(state: 'incomplete'))]
      end

      # The only two labels that are countable nouns, so the only two that need
      # agreeing with their figure — "1 reindexes" reads as a bug.
      def repository_figures(counts, day)
        cascades = counts['cascades'].to_i
        reindexes = counts['reindexes'].to_i
        # "reindex" is spelled out rather than inflected: the pluralizer reads it
        # as a Latin -ex and returns "reindices".
        [digest_figure(cascades, 'visibility change'.pluralize(cascades),
                       admin_ledger_path(tab: 'activity', kind: 'visibility_cascade', on: day)),
         digest_figure(reindexes, reindexes == 1 ? 'reindex' : 'reindexes',
                       admin_ledger_path(tab: 'activity', kind: 'set_reindex', on: day))]
      end

      def showcase_figures(showcases, day)
        path = admin_ledger_path(tab: 'activity', kind: 'showcase_promotion', on: day)
        [digest_figure(showcases['promoted'], 'published', path),
         digest_figure(showcases['refused'], 'refused', path)]
      end
  end
end
