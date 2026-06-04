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
AtlasRb.configure do |config|
  config.default_nuid         = -> { Current.nuid }
  config.default_on_behalf_of = -> { Current.on_behalf_of }
end
