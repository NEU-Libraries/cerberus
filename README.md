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
  1.  bundle install  
  2.  rake db:migrate 
  3.  rails g hydra:jetty 
  4.  rake jetty:config 


### Starting Sufia 

1.  Run the following commands:
  1.  rake jetty:start 
  2.  redis-server
  3.  COUNT=4 QUEUE=* rake environment resque:work
  4.  rails server 