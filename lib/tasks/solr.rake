namespace :solr do
  desc "Enqueue a job to resolrize the repository objects"
  task :reindex => :environment do
    Cerberus::Application::Queue.push(ResolrizeJob.new)
  end
end
