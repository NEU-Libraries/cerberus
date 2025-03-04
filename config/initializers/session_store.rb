# Be sure to restart your server when you modify this file.

# Cerberus::Application.config.session_store :cookie_store, key: '_cerberus_app_session'

# Cerberus::Application.config.session_store :redis_store,
#   servers: ["redis://nb9667.neu.edu:6379/0/session"],
#   key: '_cerberus_app_session'

Cerberus::Application.config.session_store :redis_store, {
  servers: [
    { url: "redis://nb9667.neu.edu:6379/0/session", password: ENV["REDIS_PASSWD"], expires_in: 1.month, timeout: 10.0, reconnect_attempts: 10, tcp_keepalive: 300 },
  ],
  key: '_cerberus_app_session',
  expires_in: 1.month
}

# config.cache_store = :redis_store, 'redis://localhost:6379/0/cache', { expires_in: 90.minutes }

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rails generate session_migration")
# Cerberus::Application.config.session_store :active_record_store
