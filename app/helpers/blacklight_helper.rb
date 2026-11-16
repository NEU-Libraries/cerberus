# frozen_string_literal: true

# Shadows the gem's BlacklightHelper, which Blacklight::Controller adds after
# ApplicationHelper, so an override placed in ApplicationHelper would lose.
# See docs/identity.md#a-guest-has-no-session.
module BlacklightHelper
  include Blacklight::BlacklightHelperBehavior

  # Blacklight's default arguments read search_session, which writes an empty
  # hash into the session even with tracking off. That stores a sessions row for
  # every guest who sees a result list.
  def session_tracking_params(...)
    return {} unless blacklight_config.track_search_session.storage

    super
  end
end
