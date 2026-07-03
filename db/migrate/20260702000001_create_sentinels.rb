# frozen_string_literal: true

class CreateSentinels < ActiveRecord::Migration[8.0]
  def change
    create_table :sentinels do |t|
      # The Collection or Compilation (Set) noid this Sentinel governs: its
      # per-tier policy is the default for Works created under a Collection, and
      # is bulk-applied across a Set's Works.
      t.string :target_id, null: false
      # Sparse per-tier read-group policy — { "small" => [groups], "medium" => …,
      # "large" => …, "service" => … }. An absent tier inherits the Work's own gate.
      t.jsonb :policy, null: false, default: {}
      t.timestamps
    end
    add_index :sentinels, :target_id, unique: true
  end
end
