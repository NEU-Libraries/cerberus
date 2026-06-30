# frozen_string_literal: true

# A multipage manifest now carries many items, each becoming its own Work, so
# Sequence resets per item and repeats across the report. item_index groups a
# row to its item-block *before* a Work exists (the item job stamps work_pid
# later), and the uniqueness of page order moves from (load_report, sequence)
# to (load_report, item_index, sequence). Failed/structural rows leave both
# nil — PG unique indexes admit multiple NULLs.
class AddItemIndexToMultipageIngests < ActiveRecord::Migration[8.0]
  def change
    add_column :multipage_ingests, :item_index, :integer

    remove_index :multipage_ingests, column: %i[load_report_id sequence], unique: true
    add_index :multipage_ingests, %i[load_report_id item_index sequence], unique: true
  end
end
