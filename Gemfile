source 'https://rubygems.org'

gem 'rails', '3.2.13'

# Bundle edge Rails instead:
# gem 'rails', :git => 'git://github.com/rails/rails.git'

gem 'sqlite3'

gem 'blacklight'
gem 'hydra-head'

gem 'sufia', :path => '~/neu_sufia'
#gem 'sufia', :git => 'https://github.com/nu-lts/nu-sufia.git', :branch => 'develop'
gem 'kaminari', github: 'harai/kaminari', branch: 'route_prefix_prototype'  # required to handle pagination properly in dashboard. See https://github.com/amatsuda/kaminari/pull/322

gem 'jettywrapper'

gem "bootstrap-sass", "~> 2.3.2.1"
gem 'font-awesome-sass-rails'

gem 'rspec-rails'

# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'sass-rails',   '~> 3.2.3'
  gem 'coffee-rails', '~> 3.2.1'

  gem 'compass' 
  gem 'compass-rails'

  # See https://github.com/sstephenson/execjs#readme for more supported runtimes
  # gem 'therubyracer', :platforms => :ruby

  gem 'uglifier', '>= 1.0.3'
end

gem 'jquery-rails'

gem "devise"
gem "devise-guests", "~> 0.3"



group :development, :test do
  gem "rspec-rails"
  gem "jettywrapper"
end
