


function ccloud::env::apply_list() {
	for ENV_ENCODED in $(echo $1 | jq -c -r '.[] | @base64'); do
		
		ENV=$(echo "${ENV_ENCODED}" | base64 --decode)
		
		local envname=$(echo $ENV | jq -r .name)
		local env_id=$(ccloud::env::apply name="$envname")

		echo "environment: $envname, id = $env_id"

	done
}
