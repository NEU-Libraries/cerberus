# frozen_string_literal: true

# The day an impression counts toward: its calendar date in the app's time zone,
# not in UTC. See docs/analytics.md.
#
# Impression times are stored as UTC in a plain `timestamp`, so `::date` alone
# gives the UTC date, and anything after 7 or 8 p.m. Eastern lands on tomorrow.
module ImpressionDay
  # The IANA name, which Postgres resolves with its own DST rules.
  def self.zone
    Time.zone.tzinfo.name
  end

  # SQL for the local date of a UTC timestamp column or expression.
  def self.of(column)
    "((#{column}) AT TIME ZONE 'UTC' AT TIME ZONE #{ActiveRecord::Base.connection.quote(zone)})::date"
  end

  # The UTC instants a range of local dates covers, for filtering a UTC column:
  # local midnight of the first day up to, not including, local midnight after
  # the last. Each side is its own day's midnight, so a DST day is 23 or 25 hours.
  def self.utc_bounds(dates)
    first = Time.zone.local(dates.begin.year, dates.begin.month, dates.begin.day)
    after = Time.zone.local(dates.end.year, dates.end.month, dates.end.day).tomorrow
    (first.utc...after.utc)
  end
end
