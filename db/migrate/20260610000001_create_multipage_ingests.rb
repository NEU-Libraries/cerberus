# frozen_string_literal: true

class CreateMultipageIngests < ActiveRecord::Migration[8.0]
  def change
    create_table :multipage_ingests do |t|
      t.references :load_report, null: false, foreign_key: true
      t.integer :status, null: false, default: 0
      t.string :work_pid
      t.string :source_filename
      t.string :idempotency_key
      t.text :error_message
      t.text :warnings, default: '[]'
      # 1..n page order within the one shared Work; nil on the
      # structural-failure row the unzip job writes for manifest-level
      # errors (PG unique indexes admit multiple NULLs).
      t.integer :sequence
      # Retry bookkeeping: FileSet.update (the binary PATCH) appends a new
      # Blob on every call, so a retried job must know how far the previous
      # attempt got. file_set_pid is stamped right after FileSet.create;
      # blob_attached_at right after the binary attach succeeds.
      t.string :file_set_pid
      t.datetime :blob_attached_at

      t.timestamps
    end

    add_index :multipage_ingests, %i[load_report_id sequence], unique: true
  end
end
