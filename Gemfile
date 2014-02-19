source 'https://rubygems.org'

gem 'rails', '3.2.13'

# Bundle edge Rails instead:
# gem 'rails', :git => 'git://github.com/rails/rails.git'

gem 'mysql2' # Used in staging environment. 
gem 'sqlite3'

gem 'blacklight'
gem 'hydra-head'

gem 'solrizer', :git => 'https://github.com/projecthydra/solrizer.git', :ref => 'master'

gem 'sufia', :git => 'https://github.com/nu-lts/nu-sufia.git', :ref => 'develop' #Using 'ref' instead of 'branch'. It seems branch doesn't always get the latest code, as one would expect.
gem 'kaminari', :git => 'https://github.com/harai/kaminari.git', :ref => 'route_prefix_prototype'  # required to handle pagination properly in dashboard. See https://github.com/amatsuda/kaminari/pull/322

gem 'omniauth'
gem 'omniauth-shibboleth'
gem 'hashie'

gem 'figaro'

gem 'jettywrapper'

gem 'bootstrap-sass', '~> 2.3.2.1'

gem 'haml'


# See Bower Front-End Package Management http://bower.io Documentation
gem "bower-rails", "~> 0.5.0"

#Google Analytics integration - 
gem 'google-analytics-rails'

#Google API Ruby Client
gem 'google-api-client'


gem 'webshims-rails'

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

# Use whenever for scheduling timed tasks
gem "whenever", :require => false

# Add resque-web to the project 
gem 'resque', :require => 'resque/server'

# This is global because it's needed for some fixture generation. 
gem "factory_girl_rails", :require => false

group :development do 
  # Deployment
  gem 'capistrano',  '~> 3.0.0'
  gem 'capistrano-rails'
  gem 'capistrano-bundler'
  gem 'rvm1-capistrano3', require: false
  gem 'rb-readline'
end

group :development, :test do
  gem 'guard-livereload'
  gem "rspec-rails"
  gem "capybara" 
  gem "launchy" 
  gem "jettywrapper"
  
  # JS  testing framework.
  gem "jasmine"
  
  # jQuery Testing for Rails Apps
  # @link https://github.com/travisjeffery/jasmine-jquery-rails
  gem "jasmine-jquery-rails"

end

group :test do 
  gem "resque_spec"
end
