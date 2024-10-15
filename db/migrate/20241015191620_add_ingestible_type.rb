class AddIngestibleType < ActiveRecord::Migration[7.2]
  def change
    add_column :ingests, :ingestible_type, :string
  end
end
