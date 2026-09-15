# frozen_string_literal: true

# View predicates for the Work deposit and edit surfaces.
module WorksHelper
  # Whether a record already carries values the Advanced form owns. Drives the
  # deposit disclosure's `open` state: closed is right for the ordinary deposit
  # (a filename title and nothing else), but a record that arrived with parts or
  # creators must not hide them behind a click the depositor has no reason to
  # make.
  def advanced_metadata_present?(advanced)
    advanced = advanced.to_h
    return true if advanced.values_at(:subtitle, :part_name, :part_number, :non_sort).any?(&:present?)

    advanced.values_at(:personal_creators, :corporate_creators).any? { |set| Array(set).any? }
  end
end
