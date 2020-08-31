#!/usr/bin/env bash

BASE_URL=${BASE_URL:-http://connect}

# Converts the Java properties style files located
# in CONFIG_FILE_PATH, into a string of arguments that can be passed
# into jq for file templating.
function load_configs() {

  for f in /etc/config/connect-operator/*.properties; do (cat "${f}"; echo) >> /etc/config/connect-operator/connect-operator.properties; done

  # read all the lines from the aggregate properties file and load them
  # up into arguments with keys and values
  JQ_ARGS_FROM_CONFIG_FILE=$(
  while read line
  do
  	[[ ! -z "$line" ]] && {
      # this will turn a java properties file key like:
      # schema.registry.basic.auth.user.info
      # into
      # SCHEMA_REGISTRY_BASIC_AUTH_USER_INFO
  		KEY=$(echo ${line} | cut -d= -f1 | tr '[a-z]' '[A-Z]' | tr '.' '_')
  		VALUE=$(echo ${line} | cut -d= -f2)
  		echo -n "--arg ${KEY} \"${VALUE}\" "
  	}
  done < /etc/config/connect-operator/connect-operator.properties)

  # The end result is, JQ_ARGS_FROM_CONFIG_FILE looks something like this:
  #
  # echo $JQ_ARGS_FROM_CONFIG_FILE
  # --arg BOOTSTRAP_SERVERS abc.us-east2.confluent.cloud:9092 --arg SCHEMA_REGISTRY_URL https://sr.us-east2.confluent.cloud

}

function delete_connector() {
	trap 'rm -f "$TMPFILE"' EXIT
	TMPFILE=$(mktemp) || exit 1
  echo $1 > $TMPFILE

	TEMPLATE_COMMAND="jq -c -n $JQ_ARGS_FROM_CONFIG_FILE -f $TMPFILE"

  DESIRED_CONNECTOR_CONFIG=$(eval $TEMPLATE_COMMAND | jq -c '.config')
  CONNECTOR_NAME=$(echo $DESIRED_CONNECTOR_CONFIG | jq -r '.name')
  echo "deleting connector $CONNECTOR_NAME"
	curl -s -o /dev/null -XDELETE "$BASE_URL/connectors/$CONNECTOR_NAME"
}

function apply_connector() {
	trap 'rm -f "$TMPFILE"' EXIT
	TMPFILE=$(mktemp) || exit 1
  echo $1 > $TMPFILE

	TEMPLATE_COMMAND="jq -c -n $JQ_ARGS_FROM_CONFIG_FILE -f $TMPFILE"

  DESIRED_CONNECTOR_CONFIG=$(eval $TEMPLATE_COMMAND)
  CONNECTOR_NAME=$(echo $DESIRED_CONNECTOR_CONFIG | jq -r '.name')
	CONNECTOR_EXISTS_RESULT=$(curl -s -o /dev/null -I -w "%{http_code}" -XGET -H "Accpet: application/json" "$BASE_URL/connectors/$CONNECTOR_NAME")

  [[ "$CONNECTOR_EXISTS_RESULT" == "200" ]] && {
		CURRENT_CONNECTOR_CONFIG=$(curl -s -XGET -H "Content-Type: application/json" "$BASE_URL/connectors/$CONNECTOR_NAME/config")
		if cmp -s <(echo $DESIRED_CONNECTOR_CONFIG | jq -S -c .) <(echo $CURRENT_CONNECTOR_CONFIG | jq -S -c .); then
			echo "No config changes for $CONNECTOR_NAME"
		else
			echo "Updating existing connector config: $CONNECTOR_NAME"
      DESIRED_CONNECTOR_CONFIG=$(echo $DESIRED_CONNECTOR_CONFIG | jq -S -c '.config')
    	curl -s -o /dev/null -XPUT -H "Content-Type: application/json" --data "$DESIRED_CONNECTOR_CONFIG" "$BASE_URL/connectors/$CONNECTOR_NAME/config"
		fi
  } || {
    echo "creating new connector: $CONNECTOR_NAME"
    curl -s -o /dev/null -XPOST -H "Content-Type: application/json" --data "$DESIRED_CONNECTOR_CONFIG" "$BASE_URL/connectors"
  }
}

if [[ $1 == "--config" ]]; then
  cat <<EOF
configVersion: v1
kubernetes:
- name: ConnectConfigMapMonitor
  apiVersion: v1
  kind: ConfigMap
  executeHookOnEvent: ["Added","Deleted","Modified"]
  labelSelector:
    matchLabels:
      destination: connect
  namespace:
    nameSelector:
      matchNames: ["default"]
  jqFilter: ".data"
EOF
else
  load_configs
  TYPE=$(jq -r .[0].type $BINDING_CONTEXT_PATH)
  EVENT=$(jq -r .[0].watchEvent $BINDING_CONTEXT_PATH)

  if [[ "$TYPE" == "Synchronization" ]]; then
    KEYS=$(jq -c -r '.[0].objects | .[].object.data | keys | .[]' $BINDING_CONTEXT_PATH)
   for KEY in $KEYS; do
   	CONFIG=$(jq -c -r ".[].objects | .[].object.data | select(has(\"$KEY\")) | .\"$KEY\"" $BINDING_CONTEXT_PATH)
   	apply_connector "$CONFIG"
   done
  elif [[ "$TYPE" == "Event" ]]; then
    DATA=$(jq -r '.[0].object.data' $BINDING_CONTEXT_PATH)
    KEY=$(echo $DATA | jq -r -c 'keys | .[0]')
    CONFIG=$(echo $DATA | jq -r -c ".\"$KEY\"")
    if [[ "$EVENT" == "Deleted" ]]; then
      delete_connector "$CONFIG"
    else
     apply_connector "$CONFIG"
    fi
  fi
fi

