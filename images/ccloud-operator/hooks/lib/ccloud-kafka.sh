if [ -n "$LIB_CCLOUD_KAFKA" ]; then return; fi
LIB_CCLOUD_KAFKA=`date`

function ccloud::kafka::apply_list() {
	for KAFKA_ENCODED in $(echo $1 | jq -c -r '.[] | @base64'); do
		
		KAFKA=$(echo "${KAFKA_ENCODED}" | base64 --decode)
		echo $KAFKA
		
		#local envname=$(echo $ENV | jq -r .name)
		#local env_id=$(ccloud::env::apply name="$envname")

		#echo "environment: $envname, id = $env_id"

	done
}

#local FOUND_CLUSTER=$(ccloud kafka cluster list -o json | jq -c -r '.[] | select((.name == "'"$CLUSTER_NAME"'") and (.provider == "'"$CLUSTER_CLOUD"'") and (.region == "'"$CLUSTER_REGION"'"))')

function ccloud::kafka::apply() {
	local name cloud region
	local "${@}"
	
	result=$(ccloud environment create $name -o json 2>&1)
	retcode=$?
	if [[ $retcode -eq 0 ]]; then
		echo $result | jq -r '.id'
	elif [[ "$result" == *"already in use"* ]]; then
		ccloud environment list -o json | jq -r '.[] | select(.name=="'"$name"'") | .id'
	else
		echo $result
		return $retcode
	fi
}
