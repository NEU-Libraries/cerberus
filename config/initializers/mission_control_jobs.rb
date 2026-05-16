# frozen_string_literal: true

# Auth is handled at the routes level (staff group gate); the gem's
# default HTTP Basic auth would otherwise block our devise users.
# Setting the mattr directly because config.mission_control.jobs.* is
# read in a before_initialize block, which runs before this file.
MissionControl::Jobs.http_basic_auth_enabled = false
