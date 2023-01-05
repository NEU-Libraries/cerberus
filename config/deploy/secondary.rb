set :stage, :secondary

set :deploy_to, '/opt/cerberus/'
set :bundle_env_variables, {
  nokogiri_use_system_libraries: 1,
  http_proxy: "http://proxy.neu.edu:3128",
  https_proxy: "http://proxy.neu.edu:3128"
 }
set :bundle_bins, fetch(:bundle_bins, []).push('resque-pool', 'solrizerd')

# parses out the current branch you're on. See: http://www.harukizaemon.com/2008/05/deploying-branches-with-capistrano.html
current_branch = `git branch`.match(/\* (\S+)\s/m)[1]

# use the branch specified as a param, then use the current branch. If all fails use master branch
set :branch, ENV['branch'] || current_branch || "master" # you can use the 'branch' parameter on deployment to specify the branch you wish to deploy

set :user, 'drs'
set :rails_env, :secondary

server 'drs@nb9476.neu.edu', user: 'drs', roles: %w{web app db}

namespace :deploy do
  desc "Updating ClamAV"
  task :update_clamav do
    on roles(:app), :in => :sequence, :wait => 5 do
      execute "sudo freshclam", raise_on_non_zero_exit: false
    end
  end

  desc "Tell nokogiri to use system libs"
  task :nokogiri do
    on roles(:app), :in => :sequence, :wait => 5 do
      execute "cd #{release_path} && (RAILS_ENV=secondary bundle config build.nokogiri --use-system-libraries)"
    end
  end

  desc "Precompile"
  task :assets_kludge do
    on roles(:app), :in => :sequence, :wait => 5 do
      execute "cd #{release_path} && (RAILS_ENV=secondary rake assets:precompile)"
    end
  end

  desc "Restart workers"
  task :restart_workers do
    on roles(:app), :in => :sequence, :wait => 10 do
      sudo "service resque start"
    end
  end

  desc "Copy Figaro YAML"
  task :copy_yml_file do
    on roles(:app), :in => :sequence, :wait => 5 do
      execute "cp /etc/cerberus/application.yml #{release_path}/config/"
    end
  end

  desc 'Restart solrizerd'
  task :restart_solrizerd do
    on roles(:app), :in => :sequence, :wait => 5 do
      sudo "service solrizer start"
    end
  end

end

# Load the rvm environment before executing the refresh data hook.
# This will be necessary for any hook that needs access to ruby.
# Note the use of the rvm-auto shell in the task definition.

# These hooks execute in the listed order after the deploy:updating task
# occurs.  This is the task that handles refreshing the app code, so this
# should only fire on actual deployments.

before 'deploy:starting', 'deploy:update_clamav'
after 'deploy:updating', 'bundler:install'
after 'deploy:updating', 'deploy:copy_yml_file'
#after 'deploy:updating', 'deploy:migrate'

after 'deploy:finished', 'deploy:restart_solrizerd'
after 'deploy:finished', 'deploy:restart_workers'
