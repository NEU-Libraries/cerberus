require 'rake/task'

ZIP_URL = "http://librarystaff.neu.edu/DRSzip/new-solr-schema.zip"
Rake::Task['jetty:download'].clear

namespace :jetty do

  # Kludge. Upstream broke backwards compatability by removing the zip that was hard coded in.
  task :download do
    Jettywrapper.download
  end
end
