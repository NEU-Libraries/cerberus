require "lacquer/cache_control"

Lacquer.cache_control.configure do |config|
  config.register :static,              :url => "^/images",
                                        :expires_in => "365d"

  config.register :static,              :url => "^/stylesheets",
                                        :expires_in => "365d"

  config.register :static,              :url => "^/javascripts",
                                        :expires_in => "365d"
end
