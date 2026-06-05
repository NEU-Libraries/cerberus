# frozen_string_literal: true

# View helpers for LoadsController — status icon resolution + progress
# summary formatting. Shared between the LoadReport-level index/show
# views and the per-IptcIngest _ingest_row partial. Same shape as
# AuditEventsHelper (action descriptors keyed by event['action']);
# both turn enum-ish strings into FA icon classes for at-a-glance scan.
module LoadsHelper
  STATUS_ICONS = {
    'pending'                 => 'fa-clock',
    'processing'              => 'fa-arrows-rotate',
    'completed'               => 'fa-circle-check',
    'completed_with_warnings' => 'fa-circle-exclamation',
    'failed'                  => 'fa-circle-xmark',
    'previewing'              => 'fa-eye'
  }.freeze

  def ingest_status_icon(status)
    STATUS_ICONS.fetch(status.to_s, 'fa-circle')
  end
  alias load_report_status_icon ingest_status_icon

  # The per-row ingest relation for a report under a given loader. Each
  # loader kind has its own ingest table (iptc_ingests / xml_ingests); the
  # report-level counters tally both, but the row table shows the one this
  # loader produced.
  def report_ingests(load_report, loader)
    loader.xml? ? load_report.xml_ingests : load_report.iptc_ingests
  end

  def load_report_progress_summary(load_report)
    total = load_report.total_ingests
    return '—' if total.zero?

    parts = []
    parts << "#{load_report.completed_ingests} of #{total} completed" if load_report.completed_ingests.positive?
    parts << "#{load_report.warning_ingests} with warnings"           if load_report.warning_ingests.positive?
    parts << "#{load_report.failed_ingests} failed"                   if load_report.failed_ingests.positive?
    parts.any? ? parts.join(' · ') : "#{total} pending"
  end

  def load_report_duration(load_report)
    return '—' unless load_report.started_at && load_report.finished_at

    seconds = (load_report.finished_at - load_report.started_at).to_i
    case seconds
    when 0...60    then "#{seconds}s"
    when 60...3600 then "#{seconds / 60}m #{seconds % 60}s"
    else                "#{seconds / 3600}h #{(seconds % 3600) / 60}m"
    end
  end
end
