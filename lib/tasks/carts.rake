require 'rake/task'

namespace :carts do

  # Delete all shopping carts.
  # Should move this into a daemon at some point.
  task :clear do
    dir = "#{Rails.application.config.tmp_path}/carts"
    FileUtils.rm_rf(Dir.glob(dir)) if File.directory?(dir)
  end
end
