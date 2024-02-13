#!/bin/bash
bin/rails db:migrate RAILS_ENV=staging
rm -f /home/cerberus/web/tmp/pids/server.pid
rails assets:precompile
rails s -p 3000 -b '0.0.0.0'
