#!/bin/bash
#
# Startup script for cerberus.
#
# chkconfig: - 86 15
# description: cerberus daemon
#

# source function library
. /etc/rc.d/init.d/functions

RAILS_ROOT=/home/drs/cerberus
ENV=development
USER=drs
RETVAL=0
case "$1" in
    start)
      echo -n "Starting cerberus: "
      su - $USER -c "sudo service mysqld start"
      su - $USER -c "sudo service redis start"
      su - $USER -c "cd $RAILS_ROOT && RAILS_ENV=$ENV rake jetty:start"
      su - $USER -c "cd $RAILS_ROOT && RAILS_ENV=$ENV rails server -d"
      echo
      success
  ;;
    stop)
      echo -n "Stopping cerberus: "
      su - $USER -c "sudo service mysqld stop"
      su - $USER -c "sudo service redis stop"
      su - $USER -c "cd $RAILS_ROOT && RAILS_ENV=$ENV rake jetty:stop"
      su - $USER -c "cd $RAILS_ROOT && RAILS_ENV=$ENV kill -9 $(cat tmp/pids/server.pid)"
      echo
      success
  ;;
    *)
      echo "Usage: cerberus {start|stop}"
      exit 1
  ;;
esac

exit $RETVAL
