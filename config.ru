# This file is used by Rack-based servers to start the application.

require ::File.expand_path('../config/environment',  __FILE__)

if defined?(PhusionPassenger)
  PhusionPassenger.require_passenger_lib 'rack/out_of_band_gc'

  # Trigger out-of-band GC every 50 requests.
  use PhusionPassenger::Rack::OutOfBandGc, 50
end

run Cerberus::Application

# require 'rack/cors'
# use Rack::Cors do
#
#   # allow all origins in development
#   allow do
#     origins '*'
#     resource '/api/v1/*',
#         :headers => :any,
#         :methods => [:post, :options]
#   end
# end
