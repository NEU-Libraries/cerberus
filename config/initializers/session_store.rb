# Be sure to restart your server when you modify this file.

# Cerberus::Application.config.session_store :cookie_store, key: '_cerberus_app_session'

# Cerberus::Application.config.session_store :redis_store,
#   servers: ["redis://nb9478.neu.edu:6379/0/session"],
#   key: '_cerberus_app_session'

Cerberus::Application.config.session_store :redis_store, {
  servers: [
    { url: "redis://nb9478.neu.edu:6379/0/session", expires_in: 1.week, timeout: 10.0, reconnect_attempts: 10, tcp_keepalive: 300 },
  ],
  key: '_cerberus_app_session',
  expire_after: 1.week
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rails generate session_migration")
# Cerberus::Application.config.session_store :active_record_store
