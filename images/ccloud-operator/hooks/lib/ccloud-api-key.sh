if [ -n "$LIB_CCLOUD_API_KEY" ]; then return; fi
LIB_CCLOUD_API_KEY=`date`

source $SHELL_OPERATOR_HOOKS_DIR/lib/common.sh

function ccloud::api_key::create_from_list() {
	local api_key resource_id
	local "${@}"
  
	for API_KEY_ENCODED in $(echo $api_key | jq -c -r '.[] | @base64'); do
		
		API_KEY=$(echo "${API_KEY_ENCODED}" | base64 -d)

    local name=$(echo $API_KEY | jq -r '.name')
    local service_account=$(echo $API_KEY | jq -r '."service-account"')

    key_result=$(ccloud::api_key::create resource_id="$resource_id" service_account="$service_account")
      
	done
}

function ccloud::api_key::create() {
  local resource_id service_account
  local "${@}"
  local sa_id=$(ccloud::sa::get_id name=$service_account) && {
    local result=$(ccloud api-key create --service-account $sa_id --resource $resource_id -o json 2>&1) && {
      echo $result | jq -r -c '.'
    } || {
      echo "error configuring api-key: $result"
      return $CCLOUD_ERROR
    }
  } || {
    echo "error retrieving service account id for $service_account"
    return $SERVICE_ACCOUNT_NOT_FOUND
  }
}

