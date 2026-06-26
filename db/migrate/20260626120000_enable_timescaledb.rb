# frozen_string_literal: true

# Activate the TimescaleDB extension in Cerberus's primary database. The dev
# `db` image (timescale/timescaledb:*-pg14) ships the extension available but
# inactive; this turns it on for *this* logical DB only, so the shared Atlas DB
# on the same service is unaffected. Kept in its own migration (extension
# creation before any hypertable DDL).
class EnableTimescaledb < ActiveRecord::Migration[8.1]
  def up
    execute 'CREATE EXTENSION IF NOT EXISTS timescaledb'
  end

  def down
    execute 'DROP EXTENSION IF EXISTS timescaledb'
  end
end
