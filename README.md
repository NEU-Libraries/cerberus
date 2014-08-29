[![Build Status](https://travis-ci.org/NEU-Libraries/cerberus.svg?branch=develop)](https://travis-ci.org/NEU-Libraries/cerberus)
[![Coverage Status](https://img.shields.io/coveralls/NEU-Libraries/cerberus.svg)](https://coveralls.io/r/NEU-Libraries/cerberus?branch=develop)

### DRS Application

A web application derived from the [Sufia](http://github.com/projecthydra/sufia) gem provided by Project Hydra.

### First Time Setup

1.  Ensure that you have the following installed.
  1.  SQLite
  2.  Redis
  3.  Ruby with RVM or some other version management solution.
  4.  [FITS](http://code.google.com/p/fits/downloads/list).  Unzip this and place it somewhere on your path.
  5.  Imagemagick
  6.  `yum install file-devel` may be necessary to get the ruby-filemagic gem working on RHEL machines.
  7.  You will also need to install [LibreOffice](www.libreoffice.org/download) and get the 'soffice' script onto your path.  On OSX this lives at `/Applications/LibreOffice.app/Contents/MacOS/`

2.  Execute the following commands from project root.
  1.  `bundle install`
  2.  `rake db:migrate`
  3.  `rails g hydra:jetty`
  4.  `rake jetty:config`


### Starting the DRS

1.  Run the following commands:
  1.  `rake jetty:start`
  2.  `redis-server`
  3.  `COUNT=4 QUEUE=* rake environment resque:workers`
  4.  `rails server`


### Developing Notes

Make sure to use the editorconfig plugin for whatever editor you prefer. [Download a plugin](http://editorconfig.org/#download)


Tests run with `$ rspec`

[capybara cheat sheet](https://gist.github.com/zhengjia/428105)

#### Guard / Livereload

You will also need the chrome livereload extension.

`$ bundle exec guard start -P livereload`
