# Automate deployment to our local dev machine.
# This somewhat deceptively requires the use of an environment called 'staging' 
# Which is really just develop with the caveat that jetty runs on port 3000.

# Sorry.

set :stage, :development

set :deploy_to, '/home/drs/apps/develop/'
set :branch, 'develop'

set :user, 'drs'
set :rails_env, :staging

server 'drs@repositorydev.neu.edu', user: 'drs', roles: %w{web app db}

namespace :deploy do 
  desc "Restarting application"
  task :restart do 
    on roles(:app), :in => :sequence, :wait => 5 do 
      sudo "service httpd restart"
    end
  end

  desc "Precompile"
  task :assets_kludge do 
    on roles(:app), :in => :sequence, :wait => 5 do 
      execute "cd #{release_path} && (RAILS_ENV=staging /tmp/drs/rvm-auto.sh . rake assets:precompile)" 
    end
  end

  desc "Instantiate the drsadmin user" 
  task :create_drs_admin do 
    on roles(:app), :in => :sequence, :wait => 5 do 
      execute "cd #{release_path} && (RAILS_ENV=staging /tmp/drs/rvm-auto.sh . rake create_drs_admin)" 
    end
  end

  desc "Resetting data" 
  task :refresh_data do 
    on roles(:app), :in => :sequence, :wait => 5 do
      # execute "cd #{release_path} && (RAILS_ENV=staging /tmp/drs/rvm-auto.sh . rake jetty:stop)" 
      # execute "cd #{release_path} && (RAILS_ENV=staging /tmp/drs/rvm-auto.sh . rake reset_data)"
    end
  end
end

# Load the rvm environment before executing the refresh data hook.
# This will be necessary for any hook that needs access to ruby. 
# Note the use of the rvm-auto shell in the task definition. 
before 'deploy:refresh_data', 'rvm1:hook' 

# These hooks execute in the listed order after the deploy:updating task
# occurs.  This is the task that handles refreshing the app code, so this 
# should only fire on actual deployments. 
after 'deploy:updating', 'bundler:install'
after 'deploy:updating', 'deploy:migrate'
after 'deploy:migrate',  'deploy:create_drs_admin'
after 'deploy:updating', 'deploy:restart' 
after 'deploy:updating', 'deploy:assets_kludge'
# after 'deploy:finished', 'deploy:refresh_data'