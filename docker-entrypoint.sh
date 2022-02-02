#!/bin/bash
dockerize -wait tcp://db:5432 -timeout 1m
rm -f /home/cerberus/web/tmp/pids/server.pid
rails s -p 3000 -b '0.0.0.0'
