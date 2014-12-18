# Load the rails application
require File.expand_path('../application', __FILE__)

# Initialize the rails application
Cerberus::Application.initialize!

Haml::Template.options[:ugly] = true
