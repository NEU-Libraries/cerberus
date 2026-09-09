# frozen_string_literal: true

# The per-request backstop. Puma has no request timeout, so without this the
# only bounds are the per-client deadlines (Atlas, Solr, Cantaloupe, the schema
# host, Postgres) — and those are per call, not per request, so a page that
# makes several sequential calls can still add up to far longer than any one of
# them. See docs/development.md.
#
# Inserted at position 0 so the deadline covers the whole stack rather than
# whatever sits below it. Streaming routes are exempt, which is the reason this
# is mounted by hand instead of by the gem's railtie — see lib/request_deadline.rb.
#
# 20s is about forty-five times the measured p50 of the heaviest page. It is
# deliberately above every per-client deadline so those fire first: they name
# the dependency that failed, while this one only says the request ran too long.
require 'request_deadline'

Rails.application.config.middleware.insert 0, RequestDeadline, service_timeout: 20
