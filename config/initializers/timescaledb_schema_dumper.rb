# frozen_string_literal: true

# TimescaleDB files a continuous aggregate's refresh policy under the
# materialization hypertable's name before 2.20 and under the view's name from
# 2.20 on. The timescaledb gem joins on one name only, so on the other side of
# 2.20 db/schema.rb drops refresh_policies. Matching either name works on both.
# See docs/analytics.md.
Rails.application.config.to_prepare do
  Timescaledb::ContinuousAggregates.has_many :jobs,
                                             lambda { |aggregate|
                                               unscope(where: :hypertable_name)
                                                 .where(hypertable_name: [aggregate.view_name,
                                                                          aggregate.materialization_hypertable_name])
                                             },
                                             foreign_key: 'hypertable_name',
                                             class_name:  'Timescaledb::Job'
end
