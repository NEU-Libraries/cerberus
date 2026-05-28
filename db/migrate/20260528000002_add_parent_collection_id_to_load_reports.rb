# frozen_string_literal: true

class AddParentCollectionIdToLoadReports < ActiveRecord::Migration[8.0]
  def change
    add_column :load_reports, :parent_collection_id, :string
  end
end
