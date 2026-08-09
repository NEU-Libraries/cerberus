# frozen_string_literal: true

class CreateStaffRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :staff_requests do |t|
      # withdraw / move (a Work) or restrict (a Collection or Community) — the
      # actions an editor may ask for but not perform. The kind decides both the
      # remedy the ledger links to and who is allowed to run it: only :admin can
      # fulfil a restrict, because only :admin can run a visibility cascade.
      t.string :kind, null: false
      t.string :subject_noid, null: false
      t.string :subject_type, null: false
      # Snapshot of the title at request time. Atlas is the source of truth, but a
      # ledger page lists many rows at once and must not cost one Atlas call each.
      # The row links by noid, so a later rename leaves the link correct.
      t.string :subject_title
      # Cerberus has no users table (User is session-only state hydrated from
      # Atlas), so NUID strings are the key here as they are on messages.
      t.string :requester_nuid, null: false
      t.text :note

      # open / claimed / resolved. This state is shared, which is the whole point
      # of the table: a group-addressed inbox message is dismissed per person, so
      # one person fulfilling a request leaves it unread for everyone else and
      # records nothing about who acted.
      t.string :status, null: false, default: 'open'
      t.string :claimed_by_nuid
      t.datetime :claimed_at
      t.string :resolved_by_nuid
      t.datetime :resolved_at
      # done / declined, plus the note sent back to the requester's inbox.
      t.string :resolution
      t.text :resolution_note

      t.timestamps
    end

    # The ledger's default view: open requests, oldest first.
    add_index :staff_requests, %i[status created_at]
    # "Has anyone already asked about this object?"
    add_index :staff_requests, :subject_noid
  end
end
