# Load the rails application
require File.expand_path('../application', __FILE__)

::ActiveSupport::Deprecation.silenced = true if Rails.env.production?

# Initialize the rails application
Cerberus::Application.initialize!

Haml::Template.options[:ugly] = true

if Rails.env.production? || Rails.env.secondary?
  ENV['TMPDIR'] = "/mnt/libraries/DRStmp"
end
