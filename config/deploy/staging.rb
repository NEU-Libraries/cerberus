set :stage, :staging
set :whenever_environment, 'staging'

set :deploy_to, '/home/drs/cerberus/'

# parses out the current branch you're on. See: http://www.harukizaemon.com/2008/05/deploying-branches-with-capistrano.html
current_branch = `git branch`.match(/\* (\S+)\s/m)[1]

# use the branch specified as a param, then use the current branch. If all fails use master branch
set :branch, ENV['branch'] || current_branch || "develop" # you can use the 'branch' parameter on deployment to specify the branch you wish to deploy

set :user, 'drs'
set :rails_env, :staging

server 'drs@cerberus.library.northeastern.edu', user: 'drs', roles: %w{web app db}

namespace :start do
  desc "Start Jetty"
  task :start_jetty do
    on roles(:app), :in => :sequence, :wait => 5 do
      execute "cd #{release_path} && (RAILS_ENV=staging /tmp/drs/rvm-auto.sh . bundle exec rake jetty:start_staging)"
    end
  end

  desc "Restarting application"
  task :start_httpd do
    on roles(:app), :in => :sequence, :wait => 5 do
      sudo "service httpd start"
    end
  end
end

namespace :stop do
  desc "Restarting application"
  task :stop_httpd do
    on roles(:app), :in => :sequence, :wait => 5 do
      sudo "service httpd stop"
    end
  end

  desc "Stop Jetty"
  task :stop_jetty do
    on roles(:app), :in => :sequence, :wait => 5 do
      execute "cd /home/drs/cerberus/current && (RAILS_ENV=staging /tmp/drs/rvm-auto.sh . rake jetty:stop_staging)", raise_on_non_zero_exit: false
    end
  end
end

namespace :deploy do
  desc "Restarting the resque workers"
  task :restart_workers do
    on roles(:app), :in => :sequence, :wait => 5 do
      execute "cd #{release_path} && (RAILS_ENV=staging /tmp/drs/rvm-auto.sh . bundle exec kill -TERM $(cat /home/drs/config/resque-pool.pid > /dev/null 2> /dev/null) > /dev/null 2> /dev/null); true", raise_on_non_zero_exit: false
      execute "cd #{release_path} && (RAILS_ENV=staging /tmp/drs/rvm-auto.sh . kill $(ps aux | grep -i resque | awk '{print $2}'))", raise_on_non_zero_exit: false
      execute "cd #{release_path} && (RAILS_ENV=staging /tmp/drs/rvm-auto.sh . rm -f /home/drs/config/resque-pool.pid)", raise_on_non_zero_exit: false
      execute "cd #{release_path} && (RAILS_ENV=staging /tmp/drs/rvm-auto.sh . bundle exec resque-pool --daemon -p /home/drs/config/resque-pool.pid)"
    end
  end

  desc "Clearing cache"
  task :clear_cache do
    on roles(:app), :in => :sequence, :wait => 5 do
      execute "cd #{release_path} && (RAILS_ENV=staging /tmp/drs/rvm-auto.sh . rake cache:clear)", raise_on_non_zero_exit: false # if it was never run, theres no dir
    end
  end

  desc "Make Jetty"
  task :gen_jetty do
    on roles(:app), :in => :sequence, :wait => 5 do
      # massive kludge because the zip never downloads properly...
      execute "mkdir -p #{release_path}/tmp && cd #{release_path}/tmp && wget -q http://librarystaff.neu.edu/DRSzip/new-solr-schema.zip"
      execute "cd #{release_path} && (RAILS_ENV=staging /tmp/drs/rvm-auto.sh . bundle exec rails g hydra:jetty)"
      execute "cd #{release_path} && (RAILS_ENV=staging /tmp/drs/rvm-auto.sh . bundle exec rake jetty:config)"
    end
  end

  desc "Copy Figaro YAML"
  task :copy_yml_file do
    on roles(:app), :in => :sequence, :wait => 5 do
      execute "cp /home/drs/config/application.yml #{release_path}/config/"
    end
  end

  desc "Setting whenever environment and updating the crontable"
  task :whenever do
    on roles(:app), :in => :sequence, :wait => 5 do
      execute "cd #{release_path} && (RAILS_ENV=staging /tmp/drs/rvm-auto.sh . bundle exec whenever --set environment=staging -c)"
      execute "cd #{release_path} && (RAILS_ENV=staging /tmp/drs/rvm-auto.sh . bundle exec whenever --set environment=staging -w)"
    end
  end

  desc 'Flush Redis'
  task :flush_redis do
    on roles(:app), :in => :sequence, :wait => 5 do
      execute "cd #{release_path} && (RAILS_ENV=staging /tmp/drs/rvm-auto.sh . redis-cli FLUSHALL)"
    end
  end

  desc "Copy rvmrc"
  task :copy_rvmrc_file do
    on roles(:app), :in => :sequence, :wait => 5 do
      execute "cp /home/drs/.drsrvmrc #{release_path}/.rvmrc"
    end
  end

  desc 'Trust rvmrc file'
  task :trust_rvmrc do
    on roles(:app), :in => :sequence, :wait => 5 do
      execute "/home/drs/.rvm/bin/rvm rvmrc trust #{release_path}"
    end
  end

end

# Load the rvm environment before executing the refresh data hook.
# This will be necessary for any hook that needs access to ruby.
# Note the use of the rvm-auto shell in the task definition.

before 'deploy:restart_workers', 'rvm1:hook'

# These hooks execute in the listed order after the deploy:updating task
# occurs.  This is the task that handles refreshing the app code, so this
# should only fire on actual deployments.
before 'deploy:starting', 'stop:stop_httpd'
before 'deploy:starting', 'stop:stop_jetty'

after 'deploy:updating', 'deploy:copy_rvmrc_file'
after 'deploy:updating', 'deploy:trust_rvmrc'
after 'deploy:updating', 'bundler:install'
after 'deploy:updating', 'deploy:copy_yml_file'
after 'deploy:updating', 'deploy:migrate'
after 'deploy:updating', 'deploy:whenever'
after 'deploy:updating', 'deploy:clear_cache'
after 'deploy:finished', 'deploy:flush_redis'
after 'deploy:updating', 'deploy:gen_jetty'
after 'deploy:finished', 'deploy:restart_workers'

after 'deploy:finished', 'start:start_jetty'
after 'deploy:finished', 'start:start_httpd'
