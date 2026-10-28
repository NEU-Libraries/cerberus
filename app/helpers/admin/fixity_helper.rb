# frozen_string_literal: true

module Admin
  # Cells of the admin fixity report, read from the per-Work rollup in Solr.
  # See docs/fixity.md.
  module FixityHelper
    # Absent while any of the Work's objects is unchecked, so a dash here
    # means "not every object", not "never".
    def fixity_checked_cell(doc)
      stamp = doc['work_fixity_checked_at_dtsi']
      return content_tag(:span, '—') if stamp.blank?

      parsed = Time.iso8601(stamp).in_time_zone
      content_tag(:span, parsed.strftime('%Y-%m-%d'), class: 'admin-registry-table__when', title: parsed.iso8601)
    end

    # A Work indexed before Atlas recorded checks carries no counts at all.
    def fixity_coverage_cell(doc)
      objects = doc['work_fixity_objects_isi']
      return content_tag(:span, '—') if objects.nil?

      checked = objects.to_i - doc['work_fixity_never_checked_isi'].to_i
      content_tag(:span, "#{checked} of #{objects}", class: 'admin-registry-table__when')
    end
  end
end
