#!/bin/bash
bin/rails db:migrate RAILS_ENV=development
rm -f /home/cerberus/web/tmp/pids/server.pid
rails s -p 3000 -b '0.0.0.0'
