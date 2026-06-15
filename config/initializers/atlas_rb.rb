# frozen_string_literal: true

# Hand atlas_rb a callable that resolves the acting user's NUID from the
# per-request `Current` context. atlas_rb's resource methods fall through
# to this when a `nuid:` kwarg isn't passed at the call site, so the
# explicit threading from piece 2 collapses to ambient resolution.
#
# AtlasRb::System::* paths (SSO provisioning) deliberately bypass this —
# they authenticate as the seeded :system fixture, not as the ambient user.
# AtlasRb::Admin::* paths still consult it; the `confirm: :i_understand`
# sentinel is the friction marker for destructive intent.
#
# Piece 5 (acting-as / view-as) populates `Current.on_behalf_of` during an
# acting-as session, so `default_on_behalf_of` is registered alongside
# `default_nuid`. Writes then carry `User: <admin>` + `On-Behalf-Of: <target>`
# with no per-call-site threading. Outside an acting-as session the callable
# returns nil and the header is omitted.
# Relay-signing slots (the cerberus_token replacement, atlas_rb >= 1.3.8). When
# enabled, atlas_rb signs a short-lived ES256 assertion per request — `sub` =
# the acting NUID, `iss=cerberus`, `aud=atlas` — with Cerberus's EC private key,
# in place of the `ATLAS_TOKEN` + `User:` relay. Atlas verifies it against the
# public half it holds under kid `cerberus-2026-06`.
#
# Both slots are callables resolved per request, so the cutover flag
# (config.x.cerberus.sign_assertions, from CERBERUS_SIGN_ASSERTIONS) is honoured
# live: while it's off the key callable returns nil and atlas_rb falls straight
# back to the legacy relay — nothing else changes. The gem also auto-falls-back
# to the legacy relay for any acting-as (On-Behalf-Of) request regardless of the
# flag, since Atlas 403s acting-as on the assertion path until a signed `obo`
# claim ships (a later step). The EC private key + kid live in credentials
# (cerberus_signing_key / cerberus_signing_kid), mirroring atlas_system_token.
AtlasRb.configure do |config|
  config.default_nuid         = -> { Current.nuid }
  config.default_on_behalf_of = -> { Current.on_behalf_of }

  config.assertion_signing_key = lambda do
    next nil unless Rails.application.config.x.cerberus.sign_assertions

    Rails.application.credentials.cerberus_signing_key
  end
  config.assertion_signing_kid = -> { Rails.application.credentials.cerberus_signing_kid }
end
