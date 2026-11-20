# frozen_string_literal: true

# Outside Rack::Head, so it sees the emptied HEAD body and can replace it before
# Puma sizes it. See lib/head_without_length.rb and docs/head-requests.md.
require 'head_without_length'

Rails.application.config.middleware.insert 0, HeadWithoutLength
