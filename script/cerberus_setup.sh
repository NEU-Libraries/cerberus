#!/bin/bash
(cd /home/drs/cerberus && gem install bundler)
(cd /home/drs/cerberus && bundle install --retry 5)
(cd /home/drs/cerberus && rake db:migrate)
(cd /home/drs/cerberus && rake jetty:config)
(cd /home/drs/cerberus && rake db:test:prepare)
