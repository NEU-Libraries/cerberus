# frozen_string_literal: true

class CreateLegacyIdentifiers < ActiveRecord::Migration[8.0]
  def change
    create_table :legacy_identifiers do |t|
      # The full v1 Fedora pid exactly as it arrives in the inbound URL,
      # including the `neu:` prefix and including the hand-rolled bare-integer
      # forms (`neu:1` is the root Northeastern University Community). Storing
      # the whole token means the controller looks up what it was given rather
      # than reassembling a key.
      t.string :pid, null: false
      # The fresh v2 NOID. v1 pids are not carried onto v2 objects — the pid is
      # Fedora plumbing, not object identity — so this table is the only place
      # the correspondence exists, and it is rebuilt from the migration mapping
      # rather than from the objects if it is ever lost.
      t.string :noid, null: false
      # Which v2 route to build. The destination path differs by type and the v1
      # prefix does not always match v2's (a v1 CoreFile at /files/:pid is a v2
      # Work at /works/:noid), so the type is stored rather than inferred. Held
      # here so a crawler hit costs one indexed read and no Atlas round trip.
      t.string :object_type, null: false

      t.timestamps
    end

    # The only query this table serves: one pid, on the request path.
    add_index :legacy_identifiers, :pid, unique: true
    # The reverse lookup, for the impressions historical import, which joins
    # v1 rows onto v2 objects through this same mapping.
    add_index :legacy_identifiers, :noid
  end
end
