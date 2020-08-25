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

    key_result=$(ccloud::api_key::create name="$name" resource_id="$resource_id" service_account="$service_account")
      
	done
}

function ccloud::api_key::build_api_key_secret_name() {
  local type service_account_name resource_id 
  local "${@}"
  echo "cc.api-key.$type.$service_account_name.$resource_id"
}

function ccloud::api_key::apply() {
  local type service_account_name resource_id 
  local "${@}"
  
  local sa_id=$(ccloud::sa::get_id name=$service_account_name) || {
    echo "error retrieving service account id for $service_account"
    return $SERVICE_ACCOUNT_NOT_FOUND
  }

  local secret_name=$(ccloud::api_key::build_api_key_secret_name type=$type service_account_name=$service_account_name resource_id=$resource_id)
 
  local ccloud_api_key=$(kubectl get secrets/$secret_name -o json | jq '.data' || ccloud api-key create --service-account $sa_id --resource $resource_id -o json 2>&1) || { # not a great test, kubectl could fail for perms, connectivity, etc...
    local retcode=$?
    echo "error retrieving or creating ccloud api key: $ccloud_api_key"
    return $retcode
  }
  
  local key=$(echo $ccloud_api_key | jq -r '.key')

  local result=$(kubectl create secret generic "$secret_name" --from-literal="ccloud-api-key"="$ccloud_api_key" --dry-run=client -o yaml | kubectl label -f - --dry-run=client -o yaml --local resource_id=$resource_id --local service_accont=$service_account --local service_account_id=$sa_id --local key=$key | kubectl apply -f -) && {
    echo $ccloud_api_key
  } || {
    local retcode=$?
    echo "Failed to create ccloud api key secret: $result"
    return $retcode
  }
}


