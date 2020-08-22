if [ -n "$LIB_CCLOUD_KAFKA" ]; then return; fi
LIB_CCLOUD_KAFKA=`date`

source $SHELL_OPERATOR_HOOKS_DIR/lib/common.sh
source $SHELL_OPERATOR_HOOKS_DIR/lib/ccloud-topic.sh
source $SHELL_OPERATOR_HOOKS_DIR/lib/ccloud-acl.sh
source $SHELL_OPERATOR_HOOKS_DIR/lib/ccloud-api-key.sh

function ccloud::kafka::apply_list() {
	for KAFKA_ENCODED in $(echo $1 | jq -c -r '.[] | @base64'); do
		
		KAFKA=$(echo "${KAFKA_ENCODED}" | base64 --decode)

		local name=$(echo $KAFKA | jq -r .name)
		local cloud=$(echo $KAFKA | jq -r .cloud)
		local region=$(echo $KAFKA | jq -r .region)

		local kafka_id=$(ccloud::kafka::apply name="$name" cloud="$cloud" region="$region")

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
    [[ "$api_key" != "null" ]] && ccloud::kafka::apply_secret_from_api_key_list kafka_id=$kafka_id api_key_list="$api_key"
     
	done
}

function ccloud::kafka::apply() {
	local name cloud region
	local "${@}"
	
	local FOUND_CLUSTER=$(ccloud kafka cluster list -o json | \
      jq -c -r '.[] | select((.name == "'"$name"'") and (.provider == "'"$cloud"'") and (.region == "'"$region"'"))')

  [[ ! -z "$FOUND_CLUSTER" ]] && {
      echo "$FOUND_CLUSTER" | jq -r .id
      return 0 
    } || {
      
      result=$(ccloud kafka cluster create "$name" --cloud "$cloud" --region "$region" -o json 2>&1)
			retcode=$?
			if [[ $retcode -eq 0 ]]; then
				echo $(echo $result | jq -r '.id')
        return $retcode
			else
				echo $result
				return $retcode
			fi
      return 1
    }
}

function ccloud::kafka::apply_secret_from_api_key_list() {
  local kafka_id api_key_list
  local "${@}"
  
	for API_KEY_ENCODED in $(echo $api_key_list | jq -c -r '.[] | @base64'); do
		
		API_KEY=$(echo "${API_KEY_ENCODED}" | base64 --decode)

    local name=$(echo $API_KEY | jq -r '.name')
    local service_account=$(echo $API_KEY | jq -r '."service-account"')

    ccloud::kafka::apply_secret_from_api_key name="$name" service_account="$service_account" kafka_id="$kafka_id" && {
      echo "configured api-key secret: $name"
    }

  done
}

function ccloud::kafka::apply_secret_from_api_key() {
  local name service_account kafka_id
  local "${@}"

  kubectl get secrets/"$name" > /dev/null 2>&1 || {
    local new_key=$(ccloud::api_key::create resource_id="$kafka_id" service_account="$service_account") && {
      local key=$(echo $new_key | jq '.key')
      local secret=$(echo $new_key | jq '.secret')
      result=$(kubectl create secret generic "$name" --from-literal="sasl.jaas.config"="sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username=$key password=$secret;")
    } || {
      # secret already exists so we'll just leave it be
      return 0
    }
  }

}

