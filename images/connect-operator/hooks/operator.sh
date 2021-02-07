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
  		local key=$(echo ${line} | cut -d= -f1 | tr '[a-z]' '[A-Z]' | tr '.' '_')
  		local value=$(echo ${line} | cut -d= -f2)
  		echo -n "--arg ${key} \"${value}\" "
  	}
  done < /etc/config/connect-operator/connect-operator.properties)

  # The end result is, JQ_ARGS_FROM_CONFIG_FILE looks something like this:
  #
  # echo $JQ_ARGS_FROM_CONFIG_FILE
  # --arg BOOTSTRAP_SERVERS abc.us-east2.confluent.cloud:9092 --arg SCHEMA_REGISTRY_URL https://sr.us-east2.confluent.cloud
  #
  # and jq respects these arguments which get templated into json

}

# Accepts a JSON string parameter (config) representing a
# Kafka Connnect configuration and deletes it from the Kafka Connect
# cluster located at $BASE_URL with optional credentials passed in at user_arg
function delete_connector() {
  local config user_arg
  local "${@}"

	trap 'rm -f "$tmpfile"' EXIT
	local tmpfile=$(mktemp) || exit 1
  echo $config > $tmpfile

	local template_command="jq -c -n $JQ_ARGS_FROM_CONFIG_FILE -f $tmpfile"

  local desired_connector_config=$(eval $template_command | jq -c '.config')
  local connector_name=$(echo $desired_connector_config | jq -r '.name')
  echo "deleting connector $connector_name"
	curl -s -S -XDELETE $user_arg "$BASE_URL/connectors/$connector_name"
}

# Accepts a JSON string parameter (config) representing a
# Kafka Connnect configuration and applies it to the Kafka Connect
# cluster located at $BASE_URL with optional credentials passed in at user_arg
#
# The function will pass string through the jq program in order to fill
# in any variables from either the current environment or from the
# values in the JQ_ARGS_FROM_CONFIG_FILE variable which is set on startup
# See load_configs for how those values are provided at runtime
function apply_connector() {
  local config user_arg
  local "${@}"

  if [ -z "$user_arg" ]; then
    local curl_user_opt=""
  else
    local curl_user_opt="--user '$user_arg'"
    echo "User option given: $curl_user_opt" >> debug.log
  fi;

	trap 'rm -f "$tmpfile"' EXIT
	local tmpfile=$(mktemp) || exit 1
  echo "$config" > $tmpfile

	local template_command="jq -c -n $JQ_ARGS_FROM_CONFIG_FILE -f $tmpfile"

  local desired_connector_config=$(eval $template_command)
  local connector_name=$(echo $desired_connector_config | jq -r '.name')

  # Determines if a connector already exists with this name
  echo "looking for existing connector $connector_name on $BASE_URL"
  local connector_exists_result=$(curl -o /dev/null -s -S -I -w "%{http_code}" -XGET -H "Accpet: application/json" $curl_user_opt "$BASE_URL/connectors/$connector_name")

  [[ "$connector_exists_result" == "200" ]] && {

    # If the conector already exists, we need to potentially update the configuration instead of POSTing a new connector
    # First we use `jq` to detect any changes in the desired config in the ConfigMap vs what's returned from the connector http endpoint
    echo "checking current connector config $connector_name on $BASE_URL"
		local current_connector_config=$(curl -s -S -XGET -H "Content-Type: application/json" $curl_user_opt "$BASE_URL/connectors/$connector_name/config")

		if cmp -s <(echo $desired_connector_config | jq -S -c .) <(echo $current_connector_config | jq -S -c .); then
			echo "No config changes for $connector_name"
		else
      desired_connector_config=$(echo $desired_connector_config | jq -S -c '.config')
      # Here we PUT the changed configuration to the API under the connectorname/config route
      # We output the results of the call to /dev/null to prevent leakage of secrets to logging
      # todo: better handling of errors to assist debugging
			echo "Updating existing connector config: $connector_name on $BASE_URL"
    	curl -s -S -o curl.log -XPUT -H "Content-Type: application/json" --data "$desired_connector_config" $curl_user_opt "$BASE_URL/connectors/$connector_name/config" || {
        echo "Error updating exisiting connector config: $connector_name. See "
      }
		fi

  } || {

    echo "creating new connector: $connector_name on $BASE_URL"
    curl -s -S -o curl.log -XPOST -H "Content-Type: application/json" --data "$desired_connector_config" $curl_user_opt "$BASE_URL/connectors"

  }
}

function get_cc_kafka_cluster_connect_url() {
	local cluster_configmap_name
	local "${@}"

  local cluster_info=$(kubectl get configmap/"$cluster_configmap_name" -o json)
  local env_id=$(echo $cluster_info | jq -r '.metadata.labels.environment_id')
  local cluster_id=$(echo $cluster_info | jq -r '.metadata.labels.resource_id')
  echo "https://api.confluent.cloud/connect/v1/environments/$env_id/clusters/$cluster_id"
}
function get_cc_kafka_cluster_connect_user_arg() {
  echo "$CONNECT_REST_KEY:$CONNECT_REST_SECRET"
}

hook::run() {
  if [ "${DEBUG}" == "true" ]; then set -x; fi
  load_configs

  # shell-operator gives us a wrapper around the resource we are monitoring
  # in a file located at the path of $BINDING_CONTEXT_PATH
  # The data model for this object can be found here:
  # https://github.com/flant/shell-operator/blob/master/pkg/hook/binding_context/binding_context.go

  # so first we pull out the type of update we are getting from Kubernetes
  # todo: Do we need to handle multiple update types here?
  local type=$(jq -r .[0].type $BINDING_CONTEXT_PATH)

  # A "Syncronization" Type event indicates we need to syncronize with the
  # current state of the resource, otherwise we'll get an "Event" type event.
  if [[ "$type" == "Synchronization" ]]; then

    # In the Syncronization phase, we maybe receive many object instances,
    # so we pull out each one and process them independently
    for OBJECT_ENCODED in $(jq -c -r '.[0].objects | .[] | @base64' "$BINDING_CONTEXT_PATH"); do

      local object=$(echo "${OBJECT_ENCODED}" | base64 -d)

      local cc_destination=$(echo $object | jq -r -c '.object.metadata.labels."destination.cc"')

      local keys=$(echo $object | jq -c -r '.object.data | keys | .[]')

      for KEY in $keys; do

      	local config=$(echo $object | jq -c -r ".object.data | select(has(\"$KEY\")) | .\"$KEY\"")

        if [[ "$cc_destination" != "null" ]]; then
          local cc_url=$(get_cc_kafka_cluster_connect_url cluster_configmap_name="$cc_destination")
          BASE_URL=$cc_url apply_connector config="$config" user_arg=$(get_cc_kafka_cluster_connect_user_arg)
        else
          apply_connector config="$config" user_arg=""
        fi

      done

    done

  elif [[ "$type" == "Event" ]]; then

    # The EVENT variable will containe either Added, Updated, or Deleted in the
    # case where $type == Event
    local event=$(jq -r .[0].watchEvent $BINDING_CONTEXT_PATH)
    local data=$(jq -r '.[0].object.data' $BINDING_CONTEXT_PATH)
    local cc_destination=$(jq -r -c '.[0].object.metadata.labels."destination.cc"')
    local key=$(echo $config | jq -r -c 'keys | .[0]')
    local config=$(echo $data | jq -r -c ".\"$key\"")

    if [[ "$event" == "Deleted" ]]; then
      if [[ "$cc_destination" != "null" ]]; then
        local cc_url=$(get_cc_kafka_cluster_connect_url cluster_configmap_name="$cc_destination")
        BASE_URL=$cc_url delete_connector "$config" user_arg=$(get_cc_kafka_cluster_connect_user_arg)
      else
        delete_connector config="$config" user_arg=""
      fi
    else
      if [[ "$cc_destination" != "null" ]]; then
        local cc_url=$(get_cc_kafka_cluster_connect_url cluster_configmap_name="$cc_destination")
        BASE_URL=$cc_url apply_connector config="$config" user_arg=$(get_cc_kafka_cluster_connect_user_arg)
      else
        apply_connector config="$config" user_arg=""
      fi
    fi

  fi

  if [ "${DEBUG}" == "true" ]; then set +x; fi
}

common::run_hook "$@"

