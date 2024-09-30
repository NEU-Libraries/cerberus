class CreateIngests < ActiveRecord::Migration[7.2]
  def change
    create_table :ingests do |t|
      t.string :pid, null: false
      t.string :xml_filename, null: false
      t.integer :status, null: false, default: 0

      t.timestamps
    end
  end
end
