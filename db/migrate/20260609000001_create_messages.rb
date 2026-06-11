# frozen_string_literal: true

class CreateMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :messages do |t|
      # Cerberus has no users table (User is session-only state hydrated
      # from Atlas), so NUID strings are the key throughout. A null
      # sender_nuid marks a system-sent message.
      t.string :sender_nuid
      t.string :subject, null: false
      t.text :body
      # Exactly one of these is set: a direct message to a NUID, or a
      # group-addressed message evaluated against the recipient's session
      # groups at read time — no fan-out rows.
      t.string :recipient_nuid
      t.string :recipient_group
      t.timestamps

      t.index :recipient_nuid
      t.index :recipient_group
    end

    add_check_constraint :messages,
                         '(recipient_nuid IS NULL) <> (recipient_group IS NULL)',
                         name: 'messages_exactly_one_recipient'
  end
end
