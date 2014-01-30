class FixBadReplacementOfGenericFile < ActiveRecord::Migration
  def change
    rename_column :trophies, :nu_core_file_id, :generic_file_id if Trophy.column_names.include?('nu_core_file_id')
  end
end
