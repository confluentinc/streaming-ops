#!/bin/bash

: "${CONNECTORS_PATH?Need to set CONNECTORS_PATH}"
: "${CONFIG_FILE_PATH?Need to set CONFIG_FILE_PATH}"

BASE_URL=${BASE_URL:-http://connect}
JQ_ARGS_FROM_CONFIG_FILE=$(
while read line
do
	[[ ! -z "$line" ]] && { 
		KEY=$(echo ${line} | cut -d= -f1 | tr '[a-z]' '[A-Z]' | tr '.' '_')
		VALUE=$(echo ${line} | cut -d= -f2)
		echo -n "--arg ${KEY} \"${VALUE}\" "
	}
done < $CONFIG_FILE_PATH)

for FILE in $CONNECTORS_PATH;
do
	echo ""
	echo "========================================"

  JQ="jq -c -n $JQ_ARGS_FROM_CONFIG_FILE -f $FILE"

  CONNECTOR_CONFIG=$(eval $JQ)
  CONNECTOR_NAME=$(echo $CONNECTOR_CONFIG | jq -r '.name')

	echo "Evaluating connector: $CONNECTOR_NAME"

  CONNECTOR_EXISTS_RESULT=$(curl -s -o /dev/null -I -w "%{http_code}" -XGET -H "Accpet: application/json" "$BASE_URL/connectors/$CONNECTOR_NAME")

  [[ "$CONNECTOR_EXISTS_RESULT" == "200" ]] && {
   	 
    DESIRED_CONNECTOR_CONFIG=$(echo "$CONNECTOR_CONFIG" | jq -r -c '.config')
		echo $DESIRED_CONNECTOR_CONFIG | jq -S .

		echo "vvvvvvvvvvvvvvvvvvvvvvv"
		CURRENT_CONNECTOR_CONFIG=$(curl -s -X GET -H "Content-Type: application/json" "$BASE_URL/connectors/$CONNECTOR_NAME/config")
		echo $CURRENT_CONNECTOR_CONFIG | jq -S .

		if diff <(echo $DESIRED_CONNECTOR_CONFIG | jq -S .) <(echo $CURRENT_CONNECTOR_CONFIG | jq -S .); then
			echo "No config changes for $CONNECTOR_NAME"
		else		
			echo "Updating existing connector config: $CONNECTOR_NAME"
    	curl -s -i -X PUT -H "Content-Type: application/json" --data "$DESIRED_CONNECTOR_CONFIG" "$BASE_URL/connectors/$CONNECTOR_NAME/config"
		fi
  } || {
    echo "creating new connector: $CONNECTOR_NAME"
    curl -s -i -X POST -H "Content-Type: application/json" --data "$CONNECTOR_CONFIG" "$BASE_URL/connectors"
  }

done

