class CreateFileSizeGraphs < ActiveRecord::Migration
  def change
    create_table :file_size_graphs do |t|
      t.text :json_values, :limit => 4294967295
      t.timestamps
    end
  end
end
