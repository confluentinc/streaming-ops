#!/bin/bash

: "${CONNECTORS_PATH?Need to set CONNECTORS_PATH}"
: "${CONFIG_FILE_PATH?Need to set CONFIG_FILE_PATH}"

# TODO: 
# * Populate variables from /etc/config/kafka/kafka.properties
# * template from each connector file into a temp file
# * Either
# * just curl post/put if connect can do this idempotently
#   OR
# * Check for existence of connector,
#     then either POST to /connector
#     or PUT to /connectors/<name>/config

JQ_ARGS_FROM_CONFIG_FILE=$(
while read line
do
	[[ ! -z "$line" ]] && { 
		KEY=$(echo ${line} | cut -d= -f1 | tr '[a-z]' '[A-Z]' | tr '.' '_')
		VALUE=$(echo ${line} | cut -d= -f2)
		echo -n "--arg ${KEY} \"${VALUE}\" "
	}
done < $CONFIG_FILE_PATH)

echo "jq -n $data"
for FILE in $CONNECTORS_PATH;
do
  echo "templating connector @ $FILE"
done
