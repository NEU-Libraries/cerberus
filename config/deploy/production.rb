set :stage, :production
set :whenever_environment, 'production'

set :deploy_to, '/home/drs/apps/develop/'

# parses out the current branch you're on. See: http://www.harukizaemon.com/2008/05/deploying-branches-with-capistrano.html
current_branch = `git branch`.match(/\* (\S+)\s/m)[1]

# use the branch specified as a param, then use the current branch. If all fails use master branch
set :branch, ENV['branch'] || current_branch || "develop" # you can use the 'branch' parameter on deployment to specify the branch you wish to deploy

set :user, 'drs'
set :rails_env, :production

server 'drs@repository.library.northeastern.edu', user: 'drs', roles: %w{web app db}

namespace :deploy do
  desc "Updating ClamAV"
  task :update_clamav do
    on roles(:app), :in => :sequence, :wait => 5 do
      execute "sudo freshclam"
    end
  end

  desc "Restarting application"
  task :start_httpd do
    on roles(:app), :in => :sequence, :wait => 5 do
      sudo "service httpd start"
    end
  end

  desc "Restarting application"
  task :stop_httpd do
    on roles(:app), :in => :sequence, :wait => 5 do
      sudo "service httpd stop"
    end
  end

  desc "Precompile"
  task :assets_kludge do
    on roles(:app), :in => :sequence, :wait => 5 do
      execute "cd #{release_path} && (RAILS_ENV=production /tmp/drs/rvm-auto.sh . rake assets:precompile)"
    end
  end

  desc "Restarting the resque workers"
  task :restart_workers do
    on roles(:app), :in => :sequence, :wait => 5 do
      execute "cd #{release_path} && (RAILS_ENV=production /tmp/drs/rvm-auto.sh . bundle exec kill -TERM $(cat /home/drs/config/resque-pool.pid))", raise_on_non_zero_exit: false
      execute "cd #{release_path} && (RAILS_ENV=production /tmp/drs/rvm-auto.sh . kill $(ps aux | grep -i resque | awk '{print $2}'))", raise_on_non_zero_exit: false
      execute "cd #{release_path} && (RAILS_ENV=production /tmp/drs/rvm-auto.sh . rm -f /home/drs/config/resque-pool.pid)", raise_on_non_zero_exit: false
      execute "cd #{release_path} && (RAILS_ENV=production /tmp/drs/rvm-auto.sh . bundle exec resque-pool --daemon -p /home/drs/config/resque-pool.pid)"
    end
  end

  desc "Clearing cache"
  task :clear_cache do
    on roles(:app), :in => :sequence, :wait => 5 do
      execute "cd #{release_path} && (RAILS_ENV=production /tmp/drs/rvm-auto.sh . rake cache:clear)"
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
      execute "cd #{release_path} && (RAILS_ENV=production /tmp/drs/rvm-auto.sh . bundle exec whenever --set environment=production -c)"
      execute "cd #{release_path} && (RAILS_ENV=production /tmp/drs/rvm-auto.sh . bundle exec whenever --set environment=production -w)"
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

  desc 'Start solrizerd'
  task :start_solrizerd do
    on roles(:app), :in => :sequence, :wait => 5 do
      execute "cd #{release_path} && (RAILS_ENV=production /tmp/drs/rvm-auto.sh . bundle exec solrizerd restart --hydra_home #{release_path} -p 61616 -o nb4676.neu.edu -d /topic/fedora.apim.update -s http://solr.lib.neu.edu:8080/solr)"
    end
  end

  desc 'Flush Redis'
  task :flush_redis do
    on roles(:app), :in => :sequence, :wait => 5 do
      execute "cd #{release_path} && (RAILS_ENV=production /tmp/drs/rvm-auto.sh . redis-cli FLUSHALL)"
    end
  end

  desc 'Generate Sitemap'
  task :generate_sitemap do
    on roles(:app), :in => :sequence, :wait => 5 do
      execute :rake, 'sitemap:generate'
    end
  end

end

# Load the rvm environment before executing the refresh data hook.
# This will be necessary for any hook that needs access to ruby.
# Note the use of the rvm-auto shell in the task definition.

before 'deploy:restart_workers', 'rvm1:hook'

before 'deploy:assets_kludge', 'deploy:clear_cache'

# These hooks execute in the listed order after the deploy:updating task
# occurs.  This is the task that handles refreshing the app code, so this
# should only fire on actual deployments.
before 'deploy:starting', 'deploy:stop_httpd'
before 'deploy:starting', 'deploy:update_clamav'

after 'deploy:updating', 'deploy:copy_rvmrc_file'
after 'deploy:updating', 'deploy:trust_rvmrc'
after 'deploy:updating', 'bundler:install'
after 'deploy:updating', 'deploy:copy_yml_file'
after 'deploy:updating', 'deploy:migrate'
after 'deploy:updating', 'deploy:whenever'
after 'deploy:updating', 'deploy:assets_kludge'

after 'deploy:finished', 'deploy:start_solrizerd'
after 'deploy:finished', 'deploy:flush_redis'
after 'deploy:finished', 'deploy:start_httpd'
after 'deploy:finished', 'deploy:restart_workers'
after 'deploy:finished', 'deploy:generate_sitemap'
