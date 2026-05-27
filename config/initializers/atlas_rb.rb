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
# When Cerberus piece 5 (acting-as / view-as) lands and `Current.on_behalf_of`
# starts being populated, register `config.default_on_behalf_of` here too.
AtlasRb.configure do |config|
  config.default_nuid = -> { Current.nuid }
end
