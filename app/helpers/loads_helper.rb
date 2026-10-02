# frozen_string_literal: true

# View helpers for LoadsController — status icon resolution + progress
# summary formatting. Shared between the LoadReport-level index/show
# views and the per-IptcIngest _ingest_row partial. Same shape as
# AuditEventsHelper (action descriptors keyed by event['action']);
# both turn enum-ish strings into FA icon classes for at-a-glance scan.
module LoadsHelper
  REPORT_SEVERITY = "CASE status WHEN #{Ingest.statuses['failed']} THEN 0 " \
                    "WHEN #{Ingest.statuses['completed_with_warnings']} THEN 1 ELSE 2 END".freeze

  STATUS_ICONS = {
    'pending'                 => 'fa-clock',
    'processing'              => 'fa-arrows-rotate',
    'completed'               => 'fa-circle-check',
    'completed_with_warnings' => 'fa-circle-exclamation',
    'failed'                  => 'fa-circle-xmark',
    'previewing'              => 'fa-eye'
  }.freeze

  # A load's destination as the librarians read it: "Title (PID)", linked. The
  # report polls every few seconds, so the title is cached per collection; a
  # title that cannot be read falls back to the PID alone.
  def load_destination(noid)
    return '—' if noid.blank?

    title = Rails.cache.fetch("load-destination-title/#{noid}", expires_in: 10.minutes) do
      AtlasRb::Collection.find(noid)&.dig('title').presence
    end
    link_to(title ? "#{title} (#{noid})" : noid, collection_path(noid), class: 'text-decoration-none')
  rescue AtlasRb::ResourceError, Faraday::Error, JSON::ParserError
    link_to(noid, collection_path(noid), class: 'text-decoration-none')
  end

  def ingest_status_icon(status)
    STATUS_ICONS.fetch(status.to_s, 'fa-circle')
  end
  alias load_report_status_icon ingest_status_icon

  # The per-row ingest relation for a report under a given loader. Each
  # loader kind has its own ingest table (iptc_ingests / xml_ingests /
  # multipage_ingests); the report-level counters tally all of them, but
  # the row table shows the one this loader produced.
  def report_ingests(load_report, loader)
    return load_report.multipage_ingests if loader.multipage?

    loader.xml? ? load_report.xml_ingests : load_report.iptc_ingests
  end

  # IPTC and XML rows lead with what needs attention: failures, then warnings.
  # Multipage rows are pages of several Works — group them by item, then page
  # order, since sorting pages by status would split a Work apart. NULLS FIRST
  # is explicit because Postgres sorts nulls last by default, and a
  # structural-failure row (no item, no page) belongs on top.
  def report_ingest_order(loader)
    return [Arel.sql(REPORT_SEVERITY), :source_filename] unless loader.multipage?

    table = MultipageIngest.arel_table
    [table[:item_index].asc.nulls_first, table[:sequence].asc.nulls_first]
  end

  # What this loader takes, for the never-run empty state. Kind-specific because
  # the copy used to describe IPTC-tagged JPEGs on every loader, so an operator
  # opening an XML or multipage loader was told to bring the wrong thing.
  def loader_intake_description(loader)
    case loader.kind
    when 'xml'       then 'a manifest spreadsheet with a MODS file per row'
    when 'multipage' then 'a manifest spreadsheet with a MODS file and ordered page images per item'
    else                  'an archive of IPTC-tagged JPEGs'
    end
  end

  def load_report_progress_summary(load_report)
    total = load_report.total_ingests
    return '—' if total.zero?

    completed = load_report.completed_ingests
    warnings  = load_report.warning_ingests
    failed    = load_report.failed_ingests

    parts = []
    parts << "#{completed} of #{total} completed" if completed.positive?
    parts << "#{warnings} with warnings"          if warnings.positive?
    parts << "#{failed} failed"                   if failed.positive?
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
