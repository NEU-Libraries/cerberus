#!/bin/bash
bin/rails db:migrate RAILS_ENV=staging
rm -f /home/cerberus/web/tmp/pids/server.pid
RAILS_ENV=staging rails assets:precompile
RAILS_ENV=staging bundle exec bin/jobs &
RAILS_ENV=staging rails s -p 3000 -b '0.0.0.0'
