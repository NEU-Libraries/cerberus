# frozen_string_literal: true

# Formatting for the admin replace-a-file version ledger. Mirrors the
# audit-history register (monospace identifier chips, tabular timestamps) but
# over Blob.versions descriptors ({ version_id, created, actor_nuid, digest, … })
# rather than audit events, so it can't reuse AuditEventsHelper's event-shaped
# cells directly.
module AdminFilesHelper
  # Compact UTC timestamp for a version row; muted em-dash when absent or
  # unparseable so the column still reads cleanly.
  def file_version_when(created)
    return version_empty_cell if created.blank?

    Time.iso8601(created).strftime('%Y-%m-%d %H:%M UTC')
  rescue ArgumentError
    version_empty_cell
  end

  # Actor NUID as a monospace identifier chip (same affordance as the audit-log
  # NUID pill); muted em-dash when the version carries no actor.
  def file_version_who(nuid)
    return version_empty_cell if nuid.blank?

    content_tag(:span, nuid, class: 'admin-registry-table__id')
  end

  # Fixity digest as a monospace chip, truncated to "<algo>:<first 12 hex>…" so a
  # 128-char sha512 doesn't dominate the row. The full digest rides in the title.
  def file_version_digest(digest)
    return version_empty_cell if digest.blank?

    algo, hex = digest.to_s.split(':', 2)
    shown = hex.present? ? "#{algo}:#{hex.first(12)}#{'…' if hex.length > 12}" : digest
    content_tag(:span, shown, class: 'admin-registry-table__id', title: digest)
  end

  private

    def version_empty_cell
      content_tag(:span, '—', class: 'text-muted', 'aria-hidden': 'true')
    end
end
