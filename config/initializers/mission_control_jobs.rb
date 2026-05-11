# frozen_string_literal: true

# Auth is handled at the routes level (staff group gate); the gem's
# default HTTP Basic auth would otherwise block our devise users.
Rails.application.config.mission_control.jobs.http_basic_auth_enabled = false
