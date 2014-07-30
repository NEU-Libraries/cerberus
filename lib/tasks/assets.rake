namespace :assets do
  desc "Display asset path"
  task :paths => :environment do
    Rails.application.config.assets.paths.each do |path|
      puts path
    end
  end
end