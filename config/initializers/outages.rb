# frozen_string_literal: true

# An outage exception that escapes every controller rescue reaches the exceptions
# app as a 503, not a 500, so the reader is told to wait rather than that the DRS
# is broken. See docs/outages.md.
#
# to_prepare, because Outage is reloadable and cannot be loaded while the app
# initializes.
Rails.application.config.to_prepare do
  ActionDispatch::ExceptionWrapper.rescue_responses.merge!(
    Outage.handled_errors.to_h { |error| [error.name, :service_unavailable] }
  )
end
