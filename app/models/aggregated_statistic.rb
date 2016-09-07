class AggregatedStatistic < ActiveRecord::Base
  attr_accessible :object_type, :pid, :views, :downloads, :streams, :loader_uploads, :user_uploads, :form_edits, :xml_edits, :spreadsheet_load_edits, :xml_load_edits, :size_increase, :processed_at

  # Ensure that all required fields are present
  validates :object_type, :pid, :processed_at, presence: true

end
