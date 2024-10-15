class AddIngestibleId < ActiveRecord::Migration[7.2]
  def change
    add_column :ingests, :ingestible_id, :bigint
  end
end
