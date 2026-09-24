# frozen_string_literal: true

# A result-row field that drops blank values before Blacklight decides whether
# to draw it. Blacklight hides a field only when its value array is empty, and
# a record can index an empty string (`description_tsim: [""]`), which would
# otherwise render a bare "Description:" label with nothing beside it.
class PresentValuesFieldPresenter < Blacklight::FieldPresenter
  def values
    @values ||= Array.wrap(super).compact_blank
  end
end
