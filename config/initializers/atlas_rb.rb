# frozen_string_literal: true

# Hand atlas_rb the per-request context it needs to authenticate to Atlas.
#
# `default_nuid` resolves the acting user's NUID from the per-request `Current`
# context; atlas_rb's resource methods fall through to it when a `nuid:` kwarg
# isn't passed at the call site, so call sites need no explicit threading.
# `default_on_behalf_of` resolves the acting-as / view-as target (populated on
# `Current.on_behalf_of` during an acting-as session, nil otherwise).
#
# AtlasRb::System::* paths (SSO provisioning) deliberately bypass these — they
# authenticate as the seeded :system fixture, not the ambient user. Admin paths
# still consult them; the `confirm: :i_understand` sentinel is the friction
# marker for destructive intent.
#
# Relay signing (atlas_rb >= 1.3.9) is the sole Cerberus→Atlas auth path now
# that cerberus_token is retired. Every request signs a short-lived ES256
# assertion — `sub` = the acting NUID, `iss=cerberus`, `aud=atlas`, plus a
# signed `obo` claim when acting-as — with Cerberus's EC private key; Atlas
# verifies it against the public half it holds under kid `cerberus-2026-06`.
# No `User:` / `On-Behalf-Of:` headers: identity (and the acting-as target) are
# proven in the assertion, not asserted in a forgeable header. The key + kid
# live in credentials (cerberus_signing_key / cerberus_signing_kid), mirroring
# atlas_system_token; both slots are callables resolved per request.
AtlasRb.configure do |config|
  config.default_nuid         = -> { Current.nuid }
  config.default_on_behalf_of = -> { Current.on_behalf_of }

  config.assertion_signing_key = -> { Rails.application.credentials.cerberus_signing_key }
  config.assertion_signing_kid = -> { Rails.application.credentials.cerberus_signing_kid }
end
