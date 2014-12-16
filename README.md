[![Build Status](https://travis-ci.org/NEU-Libraries/cerberus.svg?branch=develop)](https://travis-ci.org/NEU-Libraries/cerberus)
[![Coverage Status](http://img.shields.io/coveralls/NEU-Libraries/cerberus/develop.svg)](https://coveralls.io/r/NEU-Libraries/cerberus?branch=develop)

### DRS Application

A web application derived from the [Sufia](http://github.com/projecthydra/sufia) gem provided by Project Hydra.

### First Time Setup

1.  Ensure that you have the following installed.
  1.  Vagrant 1.6.5 - https://www.vagrantup.com/
  2.  VirtualBox 4.3.18 - https://www.virtualbox.org/

2.  Clone this repository
3.  Run the command ```vagrant up``` - this will instantiate the virtual machine, and provision the required cerberus software
4.  Once the above command has finished, ssh into you're instance with ```vagrant ssh```
5.  Enter the cerberus directory with ```cd ~/cerberus```
6.  Configure your relevant github information; etc. ```git config user.name "Jane Doe"``` ```git config --global user.email "jdoe@email.edu"```


### Starting the DRS

1.  Run the following commands from within the cerberus directory after ssh'ing into the instance:
  1.  `rake jetty:start`
  2.  `QUEUE=* rake environment resque:work` - this is a foreground command, you'll need a terminal tab dedicated to it
  3.  `rails server` - this is a foreground command, you'll need a terminal tab dedicated to it
