class AddIdListToAssembly < ActiveRecord::Migration[5.0]
  def change
    add_column :assemblies, :id_list, :text
  end
end
