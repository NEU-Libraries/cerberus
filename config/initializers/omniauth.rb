Rails.application.config.middleware.use OmniAuth::Builder do
  provider :shibboleth, {
    :request_type => :header,
    :shib_session_id_field     => "Shib-Session-ID",
    :shib_application_id_field => "Shib-Application-ID",
    :debug                     => false,
    :extra_fields => [
      :"unscoped-affiliation",
      :entitlement
    ]
  }
end
