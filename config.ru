# This file is used by Rack-based servers to start the application.

require ::File.expand_path('../config/environment',  __FILE__)
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
