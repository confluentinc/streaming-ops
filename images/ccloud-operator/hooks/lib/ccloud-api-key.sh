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

function ccloud::api_key::get() {
  local name resource_id
  local "${@}"

  local secret_name="cc.api-key.$name.$resource_id"
  kubectl get secrets/$secret_name -o json | jq '.data'
}

function ccloud::api_key::create() {
  local name resource_id service_account
  local "${@}"
  local sa_id=$(ccloud::sa::get_id name=$service_account) && {
    local result=$(ccloud api-key create --service-account $sa_id --resource $resource_id -o json 2>&1) && {

      local key=$(echo $result | jq '.key')
      local secret_name="cc.api-key.$name.$resource_id"

      local secret_result=$(kubectl create secret generic "$secret_name" --from-literal="$name"="$result" --dry-run=client -o yaml | kubectl label -f - --dry-run -o yaml --local resource_id=$resource_id --local service_accont=$service_account --local service_account_id=$sa_id --local key=$key | kubectl apply -f -) && {

        echo "$secret_name"

      } || {
        local retcode=$?
        echo "error adding cc.api-key secret $secret_name: $secret_result"
        return $retcode        
      }
    } || {
      echo "error creating ccloud api-key: $result"
      return $CCLOUD_ERROR
    }
  } || {
    echo "error retrieving service account id for $service_account"
    return $SERVICE_ACCOUNT_NOT_FOUND
  }
}

