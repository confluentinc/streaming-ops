if [ -n "$LIB_CCLOUD_ENV" ]; then return; fi
LIB_CCLOUD_ENV=`date`

function ccloud::env::apply_list() {
	for ENV_ENCODED in $(echo $1 | jq -c -r '.[] | @base64'); do
		
		ENV=$(echo "${ENV_ENCODED}" | base64 --decode)
		
		local envname=$(echo $ENV | jq -r .name)
		local env_id=$(ccloud::env::apply name="$envname")

		echo "environment: $envname, id = $env_id"

	done
}

####################################################################
# Apply an environment configuration with the named parameters;
# name
####################################################################
function ccloud::env::apply() {
	local name
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

##################################
# Delete a given environment 
# to the configured ccloud 
##################################
function ccloud::env::delete() {
	local id
	local "${@}"
	ccloud environment delete "$id"
}
