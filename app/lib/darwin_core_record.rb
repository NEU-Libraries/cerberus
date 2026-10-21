# frozen_string_literal: true

# Whether a Work holds a Darwin Core record. See docs/metadata-records.md.
module DarwinCoreRecord
  FORMAT = 'dwc'

  # Atlas lists the record in the Work's metadata_formats, so asking costs no
  # read. Calling Work.dwc to find out would cost one and answer nil anyway.
  def self.held_by?(work)
    Array(work&.[]('metadata_formats')).include?(FORMAT)
  end
end
