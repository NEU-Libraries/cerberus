# frozen_string_literal: true

class AddCreatorNuidToLoadReports < ActiveRecord::Migration[8.0]
  def change
    # Nothing recorded who started a load until now; finalization needs it
    # to message the right inbox. Nullable — pre-existing rows have no
    # knowable creator.
    add_column :load_reports, :creator_nuid, :string
  end
end
