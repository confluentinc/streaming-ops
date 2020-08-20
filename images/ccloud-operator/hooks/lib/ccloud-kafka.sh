if [ -n "$LIB_CCLOUD_KAFKA" ]; then return; fi
LIB_CCLOUD_KAFKA=`date`

source $SHELL_OPERATOR_HOOKS_DIR/lib/common.sh
source $SHELL_OPERATOR_HOOKS_DIR/lib/ccloud-topic.sh

function ccloud::kafka::apply_list() {
	for KAFKA_ENCODED in $(echo $1 | jq -c -r '.[] | @base64'); do
		
		KAFKA=$(echo "${KAFKA_ENCODED}" | base64 --decode)

		local name=$(echo $KAFKA | jq -r .name)
		local cloud=$(echo $KAFKA | jq -r .cloud)
		local region=$(echo $KAFKA | jq -r .region)

		local kafka_id=$(ccloud::kafka::apply name="$name" cloud="$cloud" region="$region")

		echo "kafka: $name, id = $kafka_id"
	
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

	done
}

function ccloud::kafka::apply() {
	local name cloud region
	local "${@}"
	
	local FOUND_CLUSTER=$(ccloud kafka cluster list -o json | jq -c -r '.[] | select((.name == "'"$name"'") and (.provider == "'"$cloud"'") and (.region == "'"$region"'"))')
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
