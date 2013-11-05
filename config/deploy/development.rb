# Automate deployment to our local dev machine.
# This somewhat deceptively requires the use of an environment called 'staging' 
# Which is really just develop with the caveat that jetty runs on port 3000.

# Sorry.

set :stage, :development

set :deploy_to, '/home/drs/apps/develop/'
set :branch, 'develop'

set :user, 'drs'
set :use_sudo, false
set :rails_env, :staging

server 'drs@repositorydev.neu.edu', user: 'drs', roles: %w{web app db}

namespace :deploy do 
  desc "Restarting application"
    task :restart do 
      on roles(:app), :in => :sequence, :wait => 5 do 
        sudo "service httpd restart"
      end
    end

  desc "Resetting data" 
  task :refresh_data do 
    on roles(:app), :in => :sequence, :wait => 5 do 
      run "cd #{release_path} && bundle exec rake reset_data RAILS_ENV=#{rails_env}"
    end
  end
end

after 'deploy:updating', 'deploy:migrate'
after 'deploy:updating', 'deploy:refresh_data'
after 'deploy:updating', 'deploy:restart' 