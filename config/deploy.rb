set :rvm_ruby_string,  ENV['GEM_HOME'].gsub(/.*\//,"")
set :application, 'drs'

set :scm, :git
# set :repo_url, 'git@github.com:nu-lts/drs.git'
# set :repo_url, 'git@github.com:NEU-Libraries/cerberus.git'
set :repo_url, 'https://github.com/NEU-Libraries/cerberus.git'

# ask :branch, proc { `git rev-parse --abbrev-ref HEAD`.chomp }

set :rvm_ruby_string,  ENV['GEM_HOME'].gsub(/.*\//,"")

set :deploy_via, :copy

# set :format, :pretty
set :log_level, :info
# set :pty, true

# set :linked_files, %w{config/database.yml}
# set :linked_dirs, %w{bin log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system}

# set :default_env, { path: "/opt/ruby/bin:$PATH" }

set :keep_releases, 2

set :ssh_options, {
  #  forward_agent: true,
  # verbose: :debug,
 }

namespace :deploy do

  desc 'Restart application'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      # Your restart mechanism here, for example:
      # execute :touch, release_path.join('tmp/restart.txt')
    end
  end

  after :restart, :clear_cache do
    on roles(:web), in: :groups, limit: 3, wait: 10 do
      # Here we can do anything such as:
      # within release_path do
      #   execute :rake, 'cache:clear'
      # end
    end
  end
  after :finishing, 'deploy:cleanup'
end
