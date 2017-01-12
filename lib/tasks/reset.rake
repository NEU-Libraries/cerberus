require 'active_fedora/cleaner'

namespace :reset do
  task :fixtures => :environment do
    Rake::Task['reset:clean'].invoke or exit!(1)
  end
  task :clean => :environment do
    if Rails.env.development? || Rails.env.staging?
      begin
        ActiveFedora::Cleaner.clean!
      rescue Faraday::ConnectionFailed, RSolr::Error::ConnectionRefused => e
        $stderr.puts e.message
      end
    end
  end
end
