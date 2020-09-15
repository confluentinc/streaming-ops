#!/usr/bin/env bash

source $SHELL_OPERATOR_HOOKS_DIR/lib/common.sh

BASE_URL=${BASE_URL:-http://connect}

# Converts the Java properties style files located
# in /etc/config/connect-operator into a string of arguments that can be passed
# into jq for file templating.
#
# Currently sets the global variable JQ_ARGS_FROM_CONFIG_FILE as it's "output"
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

# Accepts a single JSON string parameter representing a
# Kafka Connnect configuration and deletes it from the Kafka Connect
# cluster located at $BASE_URL
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

# Accepts a single JSON string parameter representing a
# Kafka Connnect configuration and applies it to the Kafka Connect
# cluster located at $BASE_URL
#
# The function will pass string through the jq program in order to fill
# in any variables from either the current environment or from the
# values in the JQ_ARGS_FROM_CONFIG_FILE variable which is set on startup
# See load_configs for how those values are provided at runtime
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

hook::run() {
  if [ ! -z ${DEBUG+x} ]; then set -x; fi
  load_configs

  # shell-operator gives us a wrapper around the resource we are monitoring
  # so first we pull out the type of update we are getting from Kubernetes
  TYPE=$(jq -r .[0].type $BINDING_CONTEXT_PATH)
  EVENT=$(jq -r .[0].watchEvent $BINDING_CONTEXT_PATH)

  # A "Syncronization" Type event indicates we need to syncronize with the
  # current state of the resource, otherwise we'll get an "Event" type event.
  #
  # The EVENT variable will containe either Added, Updated, or Deleted in the
  # case where TYPE == Event
  if [[ "$TYPE" == "Synchronization" ]]; then
    # In the Syncronization phase, we maybe receive many object instances,
    # so we pull out each one and process them indpendently
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
  if [ ! -z ${DEBUG+x} ]; then set +x; fi
}

common::run_hook "$@"

