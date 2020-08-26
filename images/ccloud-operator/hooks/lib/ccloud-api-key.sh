if [ -n "$LIB_CCLOUD_API_KEY" ]; then return; fi
LIB_CCLOUD_API_KEY=`date`

source $SHELL_OPERATOR_HOOKS_DIR/lib/common.sh

function ccloud::api_key::build_api_key_secret_name() {
  local service_account_name resource_id 
  local "${@}"
  echo "cc.api-key.$service_account_name.$resource_id"
}

function ccloud::api_key::apply() {
  local category service_account_name resource_id 
  local "${@}"
  
  local sa_id=$(ccloud::sa::get_id name=$service_account_name) || {
    echo "error retrieving service account id for $service_account"
    return $SERVICE_ACCOUNT_NOT_FOUND
  }

  local secret_name=$(ccloud::api_key::build_api_key_secret_name service_account_name=$service_account_name resource_id=$resource_id)
 
  local existing_secret=$(kubectl get secrets/$secret_name -o json 2>/dev/null)
  [[ ! -z "$existing_secret" ]] && {
    local ccloud_api_key=$(echo "$ccloud_api_key" | jq -r -c '.data."ccloud-api-key"')
  }

  [[ -z "$ccloud_api_key" ]] && { 
    local ccloud_api_key=$(ccloud api-key create --service-account $sa_id --resource $resource_id --description "Created by ccloud-operator $(date) for sa:$service_account_name" -o json | jq -r -c '.')
  }

  local key=$(echo $ccloud_api_key | jq -r '.key')

  local result=$(kubectl create secret generic "$secret_name" --from-literal="ccloud-api-key"="$ccloud_api_key" --dry-run=client -o yaml | kubectl label -f - --dry-run=client -o yaml --local resource_id=$resource_id --local service_accont=$service_account --local service_account_id=$sa_id --local key=$key --local category=$category | kubectl apply -f -) && {
    echo $ccloud_api_key
  } || {
    local retcode=$?
    echo "Failed to create ccloud api key secret: $result"
    return $retcode
  }

}


