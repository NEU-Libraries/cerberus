# frozen_string_literal: true

module Admin
  module MaintenanceHelper
    # Atlas sends the opening time as ISO 8601 in UTC. An unparseable value is
    # shown as sent: this page is how a window gets closed, so it must not fail.
    def maintenance_since(value)
      time = Time.iso8601(value.to_s).in_time_zone
      tag.time(time.strftime('%b %-d, %Y · %H:%M %Z'), datetime: time.iso8601)
    rescue ArgumentError
      value
    end
  end
end
