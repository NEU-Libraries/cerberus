require File.join(Rails.root, 'lib', 'asn_lookup')

Rails.application.config.after_initialize do
  AsnLookup.load! if Rails.env.production?
end
