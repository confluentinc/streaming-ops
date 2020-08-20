if [ -n "$LIB_CCLOUD_KAFKA" ]; then return; fi
LIB_CCLOUD_KAFKA=`date`

source $SHELL_OPERATOR_HOOKS_DIR/lib/ccloud-topic.sh

function ccloud::kafka::apply_list() {
	for KAFKA_ENCODED in $(echo $1 | jq -c -r '.[] | @base64'); do
		
		KAFKA=$(echo "${KAFKA_ENCODED}" | base64 --decode)

		local name=$(echo $KAFKA | jq -r .name)
		local cloud=$(echo $KAFKA | jq -r .cloud)
		local region=$(echo $KAFKA | jq -r .region)

		local kafka_id=$(ccloud::kafka::apply name="$name" cloud="$cloud" region="$region")

		echo "kafka: $name, id = $kafka_id"
	
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
				echo $result | jq -r '.id'
			else
				echo $result
				return $retcode
			fi
      return 1
    }

}
