# frozen_string_literal: true

class CreateMessageReceipts < ActiveRecord::Migration[8.0]
  def change
    create_table :message_receipts do |t|
      # Created lazily on first read/dismiss, so read state works the same
      # for direct and group-addressed messages. The composite unique index
      # below also serves the message_id lookups, so no single-column index.
      t.references :message, null: false, foreign_key: true, index: false
      t.string :nuid, null: false
      t.datetime :read_at
      t.datetime :deleted_at
      t.timestamps

      t.index %i[message_id nuid], unique: true
    end
  end
end
