if [ -n "$LIB_CCLOUD_TOPIC" ]; then return; fi
LIB_CCLOUD_TOPIC=`date`

function ccloud::topic::apply_list() {
	local kafka_id topic
	local "${@}"

	for TOPIC_ENCODED in $(echo $topic | jq -c -r '.[] | @base64'); do
		
		TOPIC=$(echo "${TOPIC_ENCODED}" | base64 --decode)

		local name=$(echo $TOPIC | jq -r .name)
		local partitions=$(echo $TOPIC | jq -r .partitions)
		local config=$(echo $TOPIC | jq -r .config)

		ccloud::topic::apply kafka_id="$kafka_id" name="$name" partitions="$partitions" config="$config" 

	done
}

function ccloud::topic::apply() {
	local kafka_id name partitions config
	local "${@}"

	local partition_flag=$([[ $partitions == "null" ]] && echo "" || echo "--partitions $partitions");
	local config_flag=$([[ "$config" == "null" ]] && echo "" || echo "--config ${config}");

	local result=$(ccloud kafka topic create "$name" --if-not-exists --cluster "$kafka_id" $partition_flag $config_flag && ccloud kafka topic describe $name --cluster "$kafka_id" -o json)
	
	echo "topic: $name" 

	local current_config=$(echo $result | jq -r -c '.config')

	[[ "$config" == "null" ]] || ccloud::topic::update name="$name" kafka_id="$kafka_id" config="$config" current_config="$current_config"	
}

function ccloud::topic::update() {
	local name kafka_id config current_config
	local "${@}"

	diff=
	while IFS=',' read -ra cfgs; do
		for c in "${cfgs[@]}"; do
			IFS='=' read -r key value <<< "$c"
			current_value=$(echo "$current_config" | jq -r '."'"$key"'"')
			[[ "$current_value" != "$value" ]] && diff=true
		done 
	done <<< "$config"

	[[ "$diff" == "true" ]] && { 
		echo "topic: $name updating config"
		ccloud kafka topic update $name --cluster $kafka_id --config $config
	} || echo "topic: $name no change"
}
