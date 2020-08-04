#!/bin/bash

: "${CONNECTORS_PATH?Need to set CONNECTORS_PATH}"

# TODO: 
# * Populate variables from /etc/config/kafka/kafka.properties
# * template from each connector file into a temp file
# * Either
# * just curl post/put if connect can do this idempotently
#   OR
# * Check for existence of connector,
#     then either POST to /connector
#     or PUT to /connectors/<name>/config
for FILE in $CONNECTORS_PATH;
do
  echo "connector found----"
  cat $FILE;
done
