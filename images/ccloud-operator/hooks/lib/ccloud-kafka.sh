if [ -n "$LIB_CCLOUD_KAFKA" ]; then return; fi
LIB_CCLOUD_KAFKA=`date`

source $SHELL_OPERATOR_HOOKS_DIR/lib/common.sh
source $SHELL_OPERATOR_HOOKS_DIR/lib/ccloud-topic.sh
source $SHELL_OPERATOR_HOOKS_DIR/lib/ccloud-acl.sh
source $SHELL_OPERATOR_HOOKS_DIR/lib/ccloud-api-key.sh

function ccloud::kafka::apply_list() {
  local kafka environment_name
  local "${@}"

	for KAFKA_ENCODED in $(echo $kafka | jq -c -r '.[] | @base64'); do

		KAFKA=$(echo "${KAFKA_ENCODED}" | base64 -d)

		local name=$(echo $KAFKA | jq -r .name)
		local cloud=$(echo $KAFKA | jq -r .cloud)
		local region=$(echo $KAFKA | jq -r .region)

		local kafka_id=$(ccloud::kafka::apply name="$name" cloud="$cloud" region="$region" environment_name="$environment_name")

		echo "configured kafka cluster: $name, id = $kafka_id"

    # When Kafka clusters are first created, they take time to initialize before they can be
    # used properly.  We're going to use the `ccloud kafka topic` command to wait until
    # no error before proceeding
    ccloud kafka cluster use "$kafka_id"
    echo "Waiting for Kafka cluster $kafka_id to be ready"
    retry 720 ccloud kafka topic list &>/dev/null || {
      echo "Kafka cluster $kafka_id never became ready"
      exit 1
    }
    echo "Kafka cluster $kafka_id is ready"

		local topic=$(echo $KAFKA | jq -r -c .topic)
		ccloud::topic::apply_list kafka_id=$kafka_id topic="$topic"

    local acl=$(echo $KAFKA | jq -r -c .acl)
    [[ "$acl" != "null" ]] && ccloud::acl::apply_list kafka_id=$kafka_id acl="$acl"

    local api_key=$(echo $KAFKA | jq -r -c '."api-key"')
    [[ "$api_key" != "null" ]] && ccloud::kafka::apply_secret_from_api_key_list kafka_id="$kafka_id" api_key_list="$api_key" environment_name="$environment_name"

	done

	return 0
}

function ccloud::kafka::apply() {
	local name cloud region environment_name
	local "${@}"

  # TODO: Determine if matching on name only is better, in the current case, changing cloud/region will
  #   result in a new cluster which may not be the intent of the user
	local FOUND_CLUSTER=$(ccloud kafka cluster list -o json | \
      jq -c -r '.[] | select((.name == "'"$name"'") and (.provider == "'"$cloud"'") and (.region == "'"$region"'"))')

  [[ ! -z "$FOUND_CLUSTER" ]] && {
      local kafka_id=$(echo "$FOUND_CLUSTER" | jq -r .id)
  } || {

    result=$(ccloud kafka cluster create "$name" --cloud "$cloud" --region "$region" -o json 2>&1)
		retcode=$?

		if [[ $retcode -eq 0 ]]; then
		  local kafka_id=$(echo $result | jq -r '.id')
		else
			echo $result
			return $retcode
		fi

  }

  ccloud::kafka::apply_kafka_description_configmap environment_name="$environment_name" kafka_id="$kafka_id"

  local secret_result=$(ccloud::kafka::apply_secret_for_endpoint kafka_id="$kafka_id" environment_name="$environment_name") && {

    echo $kafka_id
    return 0

  } || {
    local ret_code=$?
    echo "Error creating ccloud kafka secret: $secret_result"
    return $ret_code
  }
}

function ccloud::kafka::apply_secret_from_api_key_list() {
  local kafka_id api_key_list environment_name
  local "${@}"

	for API_KEY_ENCODED in $(echo $api_key_list | jq -c -r '.[] | @base64'); do

		API_KEY=$(echo "${API_KEY_ENCODED}" | base64 -d)

    local service_account=$(echo $API_KEY | jq -r '."service-account"')

    ccloud::kafka::apply_secret_for_api_key service_account="$service_account" kafka_id="$kafka_id" environment_name="$environment_name" && {
      echo "configured api-key for $service_account"
    }

  done
}

function ccloud::kafka::apply_secret_for_api_key() {
  local service_account kafka_id environment_name
  local "${@}"

  local ccloud_api_key=$(ccloud::api_key::apply category='kafka' service_account_name="$service_account" resource_id="$kafka_id") || {
    local retcode=$?
    echo "error getting ccloud api-key for $service_account:$kafka_id"
    return $retcode
  }

  local key=$(echo $ccloud_api_key | jq -r '.key')
  local secret=$(echo $ccloud_api_key | jq -r '.secret')

  local kafka_description=$(ccloud kafka cluster describe $kafka_id -o json)
  local kafka_name=$(echo $kafka_description | jq -r '.name')

  local secret_name="cc.sasl-jaas-config.$service_account.$environment_name.$kafka_name"

  local result=$(kubectl create secret generic $secret_name --from-literal="sasl-jaas-config.properties"="sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username=\"$key\" password=\"$secret\";" -o yaml --dry-run=client | kubectl apply -f -)

}

function ccloud::kafka::apply_secret_for_endpoint() {
  local kafka_id environment_name
  local "${@}"

  local kafka_description=$(ccloud kafka cluster describe $kafka_id -o json)
  local endpoint=$(echo $kafka_description | jq -r '.endpoint')
  local kafka_name=$(echo $kafka_description | jq -r '.name')
  local provider=$(echo $kafka_description | jq -r '.provider')
  local region=$(echo $kafka_description | jq -r '.region')

  local secret_name="cc.bootstrap-servers.$environment_name.$kafka_name"

  local result=$(kubectl create secret generic $secret_name --from-literal="bootstrap-servers.properties"="bootstrap.servers=$endpoint" -o yaml --dry-run=client | kubectl apply -f -)
  echo $result

}

###################################
# Updates a CC environment specific
# ConfigMap with the kafka cluster
# data
###################################
function ccloud::kafka::apply_kafka_description_configmap() {
  local environment_name kafka_id
  local "${@}"

  local environment_id=$(kubectl get configmap/cc.env."$environment_name" -o json | jq -r ".data.id")

  local kafka_description=$(ccloud kafka cluster describe --environment "$environment_id" "$kafka_id" -o json | jq -r '.')
  local kafka_name=$(echo $kafka_description | jq -r '.name')

  kubectl create configmap "cc.env.$environment_name.kafka.$kafka_name" --from-literal="description"="$kafka_description" --dry-run=client -o yaml | kubectl label -f - --dry-run=client -o yaml --local resource_id=$kafka_id --local environment_id=$environment_id | kubectl apply -f - >/dev/null 2>&1
}
