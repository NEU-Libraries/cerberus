#!/bin/bash
bin/rails db:create
bin/rails db:migrate
rm -f /home/cerberus/web/tmp/pids/server.pid
rails dartsass:watch &
# rails s -p 3000 -b '0.0.0.0'
bundle exec rdbg --open --host=0.0.0.0 --port=12345 --nonstop --command -- bin/rails server -b 0.0.0.0 -p 3000
