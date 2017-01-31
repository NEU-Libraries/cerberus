class CreateAssemblies < ActiveRecord::Migration[5.0]
  def change
    create_table :assemblies do |t|

      t.timestamps
    end
  end
end
