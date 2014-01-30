class FixBadReplacementOfGenericFile < ActiveRecord::Migration
  def change
    rename_column :trophies, :nu_core_file_id, :generic_file_id
  end
end
