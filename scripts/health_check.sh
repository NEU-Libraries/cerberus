#!/bin/bash
wget --spider --server-response localhost:3000/healthcheck 2>&1 | grep '200\ OK' | wc -l; exit_1=$?
wget --spider --server-response localhost:3000 2>&1 | grep '200\ OK' | wc -l; exit_2=$?

# Exit with error if any of the above failed. No need for a final
# call to exit, if this is the last command in the script
! (( $exit_1 || $exit_2 ))
