# frozen_string_literal: true

require 'capybara/rspec'
require 'selenium/webdriver'

# Browser specs drive Chrome in the sibling `selenium` container rather than a
# browser installed next to the app. Everything here follows from that one
# choice: the browser is a separate host, so it cannot reach a test server bound
# to this container's loopback, and it has to address the app by a name that
# resolves on the compose network.
module CapybaraRemote
  # Overridable so a run outside compose — a developer pointing at a browser on
  # their own machine — needs no edit here.
  URL = ENV.fetch('SELENIUM_REMOTE_URL', 'http://selenium:4444/wd/hub')

  # The port is fixed rather than chosen at boot, because the browser has to be
  # told the app's address before Capybara starts serving it. Puma serves the
  # development app on 3000 in this container, so the test server takes the
  # next port up.
  SERVER_PORT = 3001

  # `web` is this container's name on the compose network. Its own hostname is
  # the container ID, which nothing else can resolve.
  APP_HOST = "http://web:#{SERVER_PORT}".freeze
end

RSpec.configure do |config|
  # A config-level hook runs before the group-level one rspec-rails installs,
  # and that hook applies its own default driver only when no driver has been
  # chosen yet. Choosing one here therefore wins without suppressing anything.
  config.before(:each, type: :system) do
    driven_by :selenium, using:   :headless_chrome,
                         options: { browser: :remote, url: CapybaraRemote::URL } do |browser_options|
      # Chrome's sandbox wants kernel privileges the container is not granted.
      browser_options.add_argument('--no-sandbox')
      # Write shared memory under /tmp. The compose service raises /dev/shm as
      # well, so this is the half of the fix that survives someone running the
      # browser somewhere else.
      browser_options.add_argument('--disable-dev-shm-usage')
    end

    # Bind every interface. Capybara's default of 127.0.0.1 is unreachable from
    # the browser's container.
    served_by host: '0.0.0.0', port: CapybaraRemote::SERVER_PORT
    Capybara.app_host = CapybaraRemote::APP_HOST
  end
end
