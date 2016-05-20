namespace :ci do
  desc "Prepare for CI build"
  task :prepare => ['db:migrate', 'db:test:prepare', 'jetty:clean', 'jetty:config'] do
  end

  desc "CI build"
  task :build => :prepare do
    ENV['environment'] = "test"
    jetty_params = Jettywrapper.load_config
    jetty_params[:startup_wait] = 60
    Jettywrapper.wrap(jetty_params) do
      Rake::Task['spec'].invoke
    end
  end
end
