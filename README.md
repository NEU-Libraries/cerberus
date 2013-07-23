### DRS Sufia Application 

A web application developed using our [fork](http://github.com/nu-lts/sufia) of the [Sufia](http://github.com/projecthydra/sufia) gem from the folks over at Project Hydra.  Information about dependencies/installation can be found in either location if the provided instructions fail you.    

### First Time Setup 

1.  Ensure that you have the following installed. 
  1.  SQLite definitely, ideally also MySQL. 
  2.  Redis
  3.  Ruby with RVM or some other version management solution. 
  4.  [FITS](http://code.google.com/p/fits/downloads/list).  Unzip this and place it somewhere on your path.
  5.  Imagemagick
  6.  A local copy of the nu-lts fork of the [sufia](http://github.com/nu-lts/sufia) gem.  If you do not place it in dir ~/sufia you will need to change the path specified in Gemfile for the development copy of Sufia.     

2.  Execute the following commands from project root.
  1.  `bundle install`
  2.  `rake db:migrate`
  3.  `rails g hydra:jetty` 
  4.  `rake jetty:config`

3.  If you are running sufia on a server/in any environment where you won't have access to a local copy of Sufia, you'll need to do a quick comment/uncomment swap in the Gemfile.


### Starting Sufia 

1.  Run the following commands:
  1.  `rake jetty:start`
  2.  `redis-server`
  3.  `COUNT=4 QUEUE=* rake environment resque:work`
  4.  `rails server` 
2. or you can add something like this to you `~/.bashrc` file

    alias sufia="cd ~/{Project} & rake jetty:start & redis-server & COUNT=4 QUEUE=* rake environment resque:work & rails server"

### Developing Notes


