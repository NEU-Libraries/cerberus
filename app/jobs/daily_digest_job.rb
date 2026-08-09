# frozen_string_literal: true

# The day's closing entry on the admin ledger: what was asked, what ran, what is
# still stuck, and every work published to a community showcase.
#
# The payload is structured rather than prose because two renderers read it. The
# ledger builds paths from the noids it carries; a mailed summary will build
# absolute URLs from the same fields. A rendered link could serve neither, since
# it fixes the host — or omits it — at write time.
#
# One digest per day is enforced by a partial unique index rather than by a
# check here, so a manual re-run through `rake admin:digest` cannot double-write
# a day whatever else is in flight.
class DailyDigestJob < ApplicationJob
  queue_as :background

  # The digest is read at a glance, so the showcase list is capped and the rest
  # is a link to the filtered activity tab.
  ENTRY_CAP = 20

  def perform(day = nil)
    day = (day || Date.yesterday).to_date

    AdminNotice.create!(
      kind:        AdminNotice::DIGEST,
      subject:     "Daily digest for #{day.strftime('%B %-d, %Y')}",
      occurred_on: day,
      payload:     { counts: counts_for(day), showcases: showcases_for(day) }
    )
  rescue ActiveRecord::RecordNotUnique
    Rails.logger.info("DailyDigestJob: #{day} already has a digest — leaving it alone")
    nil
  end

  private

    def counts_for(day)
      {
        requests_opened:      StaffRequest.opened_on(day).count,
        requests_resolved:    StaffRequest.resolved_on(day).count,
        # A running total, not a figure for the day: what is still waiting is
        # the number somebody acts on.
        requests_open:        StaffRequest.unresolved.count,
        loads_run:            LoadReport.where(finished_at: day.all_day).count,
        loads_failed:         LoadReport.failed.where(finished_at: day.all_day).count,
        cascades:             AdminNotice.of_kind('visibility_cascade').on_day(day).count,
        reindexes:            AdminNotice.of_kind('set_reindex').on_day(day).count,
        deposits_unconfirmed: stuck_deposit_count(:unconfirmed),
        deposits_incomplete:  stuck_deposit_count(:incomplete)
      }
    end

    # Read from Solr with the clauses DepositTriageSearchBuilder declares, so the
    # digest and the "Deposits needing attention" page cannot drift apart. The
    # builder itself needs a controller for its scope, which a job has no way to
    # give — the clauses are the part worth sharing, not the plumbing.
    def stuck_deposit_count(state)
      fq = ['internal_resource_tesim:Work', '-tombstoned_bsi:true',
            *DepositTriageSearchBuilder::STATES.fetch(state)]
      Blacklight.default_index.search(q: '*:*', fq: fq, rows: 0).total
    rescue StandardError => e
      # A digest that cannot reach Solr is still worth writing for everything
      # else it carries.
      Rails.logger.warn("DailyDigestJob: stuck-deposit count for #{state} failed — #{e.message}")
      nil
    end

    # Grouped by community and genre in the view, because a work in the wrong
    # bucket is only visible when you scan one genre at a time.
    def showcases_for(day)
      notices = AdminNotice.of_kind('showcase_promotion').on_day(day).order(created_at: :asc)
      outcomes = notices.map { |n| n.detail(:outcome) }

      { promoted:  outcomes.count { |o| o != 'refused' },
        refused:   outcomes.count('refused'),
        entries:   notices.first(ENTRY_CAP).map { |n| entry_for(n) },
        truncated: [notices.size - ENTRY_CAP, 0].max }
    end

    def entry_for(notice)
      { community: notice.detail(:community_name), genre: notice.detail(:genre),
        title:     notice.detail(:work_title), work_noid: notice.subject_noid,
        nuid:      notice.actor_nuid, outcome: notice.detail(:outcome),
        reason:    notice.detail(:reason) }
    end
end
