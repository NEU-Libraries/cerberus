set :stage, :staging
set :whenever_environment, 'staging'

set :deploy_to, '/opt/cerberus/'

# parses out the current branch you're on. See: http://www.harukizaemon.com/2008/05/deploying-branches-with-capistrano.html
current_branch = `git branch`.match(/\* (\S+)\s/m)[1]

# use the branch specified as a param, then use the current branch. If all fails use master branch
set :branch, ENV['branch'] || current_branch || "develop" # you can use the 'branch' parameter on deployment to specify the branch you wish to deploy

set :user, 'drs'
set :rails_env, :staging

# set :rvm1_ruby_version, "2.0.0"
# fetch(:default_env).merge!( rvm_path: "/usr/local/rvm" )

set :rvm_custom_path, "/usr/local/rvm"

server 'drs@cerberus.library.northeastern.edu', user: 'drs', roles: %w{web app db}

namespace :deploy do
  desc "Restarting application"
  task :stop_httpd do
    on roles(:app), :in => :sequence, :wait => 5 do
      sudo "service httpd stop"
    end
  end

  desc "Restarting application"
  task :start_httpd do
    on roles(:app), :in => :sequence, :wait => 5 do
      execute :sudo, "service httpd start"
    end
  end

  desc "Updating ClamAV"
  task :update_clamav do
    on roles(:app), :in => :sequence, :wait => 5 do
      execute "sudo freshclam"
    end
  end

  desc "Tell nokogiri to use system libs"
  task :nokogiri do
    on roles(:app), :in => :sequence, :wait => 5 do
      execute "cd #{release_path} && (RAILS_ENV=staging bundle config build.nokogiri --use-system-libraries)"
    end
  end

  desc "Restarting the resque workers"
  task :restart_workers do
    on roles(:app), :in => :sequence, :wait => 5 do
      execute "cd #{release_path} && (RAILS_ENV=staging bundle exec kill -TERM $(cat /etc/cerberus/resque-pool.pid))", raise_on_non_zero_exit: false
      execute "kill $(ps aux | grep -i resque | awk '{print $2}')", raise_on_non_zero_exit: false
      execute "rm -f /etc/cerberus/resque-pool.pid", raise_on_non_zero_exit: false
      execute "cd #{release_path} && (RAILS_ENV=staging bundle exec resque-pool --daemon -p /etc/cerberus/resque-pool.pid)"
    end
  end

  desc "Copy Figaro YAML"
  task :copy_yml_file do
    on roles(:app), :in => :sequence, :wait => 5 do
      execute "cp /etc/cerberus/application.yml #{release_path}/config/"
    end
  end

  desc "Setting whenever environment and updating the crontable"
  task :whenever do
    on roles(:app), :in => :sequence, :wait => 5 do
      execute "cd #{release_path} && (RAILS_ENV=staging bundle exec whenever --set environment=staging -c)"
      execute "cd #{release_path} && (RAILS_ENV=staging bundle exec whenever --set environment=staging -w)"
    end
  end

  desc 'Flush Redis'
  task :flush_redis do
    on roles(:app), :in => :sequence, :wait => 5 do
      execute "cd #{release_path} && (RAILS_ENV=staging redis-cli FLUSHALL)"
    end
  end

  desc "Copy rvmrc"
  task :copy_rvmrc_file do
    on roles(:app), :in => :sequence, :wait => 5 do
      execute "cp /export/home/drs/.drsrvmrc #{release_path}/.rvmrc"
    end
  end

  desc 'Trust rvmrc file'
  task :trust_rvmrc do
    on roles(:app), :in => :sequence, :wait => 5 do
      execute "/usr/local/rvm/bin/rvm rvmrc trust #{release_path}"
    end
  end

  desc 'Build tmp dir'
  task :build_tmp_dir do
    on roles(:app), :in => :sequence, :wait => 5 do
      execute "cd #{release_path} && (mkdir tmp)"
    end
  end

end

# Load the rvm environment before executing the refresh data hook.
# This will be necessary for any hook that needs access to ruby.
# Note the use of the rvm-auto shell in the task definition.

# before 'deploy:restart_workers', 'rvm1:hook'

# These hooks execute in the listed order after the deploy:updating task
# occurs.  This is the task that handles refreshing the app code, so this
# should only fire on actual deployments.
before 'deploy:starting', 'deploy:stop_httpd'
before 'deploy:starting', 'deploy:update_clamav'

# after 'deploy:updating', 'deploy:copy_rvmrc_file'
# after 'deploy:updating', 'deploy:trust_rvmrc'
after 'deploy:updating', 'deploy:nokogiri'
after 'deploy:updating', 'bundler:install'
after 'deploy:updating', 'deploy:copy_yml_file'
after 'deploy:updating', 'deploy:migrate'
after 'deploy:updating', 'deploy:whenever'
after 'deploy:updating', 'deploy:flush_redis'

after 'deploy:finished', 'deploy:build_tmp_dir'
after 'deploy:finished', 'deploy:restart_workers'
after 'deploy:finished', 'deploy:start_httpd'
