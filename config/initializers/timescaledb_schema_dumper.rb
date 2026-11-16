# frozen_string_literal: true

# The timescaledb gem joins a continuous aggregate to its jobs on view_name,
# but TimescaleDB files a refresh policy under the materialization hypertable's
# name. Without this, db/schema.rb drops refresh_policies, and every database
# built from it (test, db:prepare) never refreshes the aggregate. See
# docs/analytics.md.
Rails.application.config.to_prepare do
  Timescaledb::ContinuousAggregates.has_many :jobs,
                                             foreign_key: 'hypertable_name',
                                             primary_key: 'materialization_hypertable_name',
                                             class_name:  'Timescaledb::Job'
end
