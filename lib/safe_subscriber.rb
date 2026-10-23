# frozen_string_literal: true

# Subscribes a block to a notification so that an error in the block is logged
# rather than raised. ActiveSupport re-raises a subscriber's error into the code
# being instrumented, so an unguarded timing subscriber that fails takes down
# the Atlas call or the page it was only meant to time. See docs/outages.md.
#
# In lib/, not app/, on purpose: a guard that is itself reloadable would raise
# NameError the moment it was renamed or removed, which is the failure it
# exists to stop.
module SafeSubscriber
  def self.subscribe(name, label:, &block)
    ActiveSupport::Notifications.subscribe(name) do |event|
      block.call(event)
    rescue StandardError => e
      Rails.logger.warn("[#{label}] subscriber failed, the request carried on: #{e.class}: #{e.message}")
    end
  end
end
