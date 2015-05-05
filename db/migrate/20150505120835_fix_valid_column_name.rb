class FixValidColumnName < ActiveRecord::Migration
  def change
    rename_column :image_reports, :valid, :validity
  end
end
