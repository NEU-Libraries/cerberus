# frozen_string_literal: true

# DB-backed sessions (ActiveRecord::SessionStore): session data lives in the
# `sessions` table rather than the cookie, lifting the ~4KB encrypted-cookie
# limit app-wide. The download queue's growing session payload needs that
# headroom; other large session writes benefit too. The cookie still carries
# only the opaque session id.
#
# ActiveRecord::SessionStore does NOT expire rows on its own — SessionTrimJob
# sweeps idle sessions past the TTL (see config/recurring.yml).
Rails.application.config.session_store :active_record_store, key: '_cerberus_session'
