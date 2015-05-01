require 'rake/task'

ZIP_URL = "http://librarystaff.neu.edu/DRSzip/new-solr-schema.zip"

# Kludge. Upstream broke backwards compatability by removing the zip that was hard coded in.

namespace :jetty do
  desc "Start staging jetty"
  task :start_staging => :environment do
    Jettywrapper.start(JETTY_CONFIG)
    puts "jetty started at PID #{Jettywrapper.pid(JETTY_CONFIG)}"
  end
  desc "Stop staging jetty"
  task :stop_staging => :environment do
    Jettywrapper.stop(JETTY_CONFIG)
    puts "jetty started at PID #{Jettywrapper.pid(JETTY_CONFIG)}"
  end
end
