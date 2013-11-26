source 'https://rubygems.org'

gem 'rails', '3.2.13'

# Bundle edge Rails instead:
# gem 'rails', :git => 'git://github.com/rails/rails.git'

gem 'sqlite3'

gem 'blacklight'
gem 'hydra-head'

#gem 'sufia', :path => '../sufia'
gem 'sufia', :git => 'https://github.com/nu-lts/nu-sufia.git', :branch => 'develop'
gem 'kaminari', :git => 'https://github.com/harai/kaminari.git', :branch => 'route_prefix_prototype'  # required to handle pagination properly in dashboard. See https://github.com/amatsuda/kaminari/pull/322

gem 'omniauth'
gem 'omniauth-shibboleth'
gem 'hashie'

gem 'activerecord-mysql2-adapter'
gem 'figaro'

gem 'jettywrapper'

gem 'bootstrap-sass', '~> 2.3.2.1'
#gem 'font-awesome-sass-rails'

gem 'haml'

# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'sass-rails',   '~> 3.2.3'
  gem 'coffee-rails', '~> 3.2.1'
  
  gem 'compass-rails'

  # See https://github.com/sstephenson/execjs#readme for more supported runtimes
  # gem 'therubyracer', :platforms => :ruby

  gem 'uglifier', '>= 1.0.3'
end

gem 'jquery-rails'

gem "devise"
gem "devise-guests", "~> 0.3"
gem "ruby-filemagic", "~> 0.4.2"

# Use figaro for setting configuration information that ought to be kept secret
gem "figaro"

# Use whenever for scheduling timed tasks
gem "whenever" 



group :development do 
  # Deployment
  gem 'capistrano',  '~> 3.0.0'
  gem 'capistrano-rails'
  gem 'capistrano-bundler'
  gem 'rvm1-capistrano3', require: false
end

group :development, :test do
  gem 'guard-livereload'
  gem "rspec-rails"
  gem "capybara" 
  gem "launchy" 
  gem "jettywrapper"
  gem "factory_girl_rails", :require => false
end

group :test do 
  gem "resque_spec" 
end
