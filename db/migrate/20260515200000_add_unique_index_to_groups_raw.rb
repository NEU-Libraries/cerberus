# frozen_string_literal: true

# Closes the cache-poisoning class for the `groups` table at the DB level.
# Before this migration, reset:clean's DatabaseCleaner call was a silent
# no-op and db/seeds.rb used Group.create!, so each rake reset:data run
# appended another full copy of the CSV. The application-level guards
# (find_or_create_by! in seeds.rb, DatabaseCleaner[:active_record] in
# reset.rake) prevent the bug from being re-introduced via those paths;
# the unique index makes it structurally impossible regardless of code
# path — `Group.create!` raises on duplicates instead of silently
# accumulating them.
class AddUniqueIndexToGroupsRaw < ActiveRecord::Migration[8.1]
  def up
    # Existing dev/staging databases may have accumulated duplicate rows
    # from the no-op-DatabaseCleaner era. Keep the oldest row per raw and
    # drop the rest before applying the unique constraint.
    execute <<~SQL
      DELETE FROM groups
      WHERE id NOT IN (SELECT MIN(id) FROM groups GROUP BY raw);
    SQL

    add_index :groups, :raw, unique: true
  end

  def down
    remove_index :groups, :raw
  end
end
