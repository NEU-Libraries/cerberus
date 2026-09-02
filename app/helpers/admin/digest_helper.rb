# frozen_string_literal: true

module Admin
  # The daily digest's count block: figures for one day, each linking to the
  # surface that lists what it counted. See docs/admin.md.
  module DigestHelper
    # @return [Array(String, String, nil)] the text, and a path or nil.
    def digest_figure(count, label, path)
      [[count.to_i, label].join(' '), (path if count.to_i.positive?)]
    end

    # The block in reading order: { label => [figure, ...] }. Every figure
    # counted one day, so every link carries that day — except the deposits.
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

      # These two carry no day: they are a live backlog, not a figure for the
      # day being summed up, so they point at the list that works them.
      def deposit_figures(counts)
        [digest_figure(counts['deposits_unconfirmed'], 'waiting on a depositor',
                       admin_deposit_triage_path(state: 'unconfirmed')),
         digest_figure(counts['deposits_incomplete'], 'missing something',
                       admin_deposit_triage_path(state: 'incomplete'))]
      end

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
