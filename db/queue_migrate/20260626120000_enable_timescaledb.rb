# frozen_string_literal: true

# Enable the (otherwise unused) timescaledb extension in the Solid Queue
# database. Nothing in the queue DB is a hypertable — this exists only to keep
# the timescaledb gem's schema dumper happy across our multi-DB setup: the gem
# memoizes "extension installed?" from the first DB it dumps (the primary, where
# timescaledb IS installed), then queries timescaledb_information.hypertables on
# the queue DB too. Without the extension present there, that query errors out
# the whole db:schema:dump. With it present, the query simply returns no
# hypertables. Inert for Solid Queue.
class EnableTimescaledb < ActiveRecord::Migration[8.1]
  def up
    execute 'CREATE EXTENSION IF NOT EXISTS timescaledb'
  end

  def down
    execute 'DROP EXTENSION IF EXISTS timescaledb'
  end
end
