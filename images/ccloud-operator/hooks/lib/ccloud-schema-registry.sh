if [ -n "$LIB_CCLOUD_SR" ]; then return; fi
LIB_CCLOUD_ENV=`date`

source $SHELL_OPERATOR_HOOKS_DIR/lib/ccloud-kafka.sh
source $SHELL_OPERATOR_HOOKS_DIR/lib/ccloud-api-key.sh

####################################################################
# Apply an schema-registry configuration given in json as the
# first parameter
####################################################################
function ccloud::schema-registry::apply() {
  local sr environment_name
  local "${@}"

  local cloud=$(echo $sr | jq -r .cloud)
  local geo=$(echo $sr | jq -r .geo)	

  local result=$(ccloud schema-registry cluster enable --cloud "$cloud" --geo "$geo" -o json)

  local sr_id=$(echo $result | jq -r '.id')

  local api_key=$(echo $sr | jq -r -c '."api-key"')
  [[ "$api_key" != "null" ]] && ccloud::schema-registry::apply_secret_from_api_key_list sr_id="$sr_id" api_key_list="$api_key" environment_name="$environment_name"

  local endpoint_result=$(ccloud::schema-registry::apply_secret_for_endpoint environment_name="$environment_name") || {
    local ret_code=$?
    echo "error creating schema-registry secret: $endpoint_result"
    return $ret_code
  }

  echo $sr_id
}

function ccloud::schema-registry::apply_secret_from_api_key_list() {
  local sr_id api_key_list environment_name
  local "${@}"
  
	for API_KEY_ENCODED in $(echo $api_key_list | jq -c -r '.[] | @base64'); do
		
		API_KEY=$(echo "${API_KEY_ENCODED}" | base64 -d)

    local service_account=$(echo $API_KEY | jq -r '."service-account"')

    ccloud::schema-registry::apply_secret_for_api_key service_account="$service_account" sr_id="$sr_id" environment_name="$environment_name"

  done
}

function ccloud::schema-registry::apply_secret_for_api_key() {
  local service_account sr_id environment_name
  local "${@}"

  local ccloud_api_key=$(ccloud::api_key::apply category='schema-registry' service_account_name="$service_account" resource_id="$sr_id") || {
    local retcode=$?
    echo "error getting ccloud api-key for $service_account:$sr_id"
    return $retcode
  }

  local key=$(echo $ccloud_api_key | jq -r .key)
  local secret=$(echo $ccloud_api_key | jq -r .secret)
 
  local secret_name="cc.schema-registry-basic-auth-user-info.$service_account.$environment_name"

  local result=$(kubectl create secret generic $secret_name --from-literal="schema-registry-basic-auth-user-info.properties"="schema.registry.basic.auth.user.info=$key:$secret" -o yaml --dry-run=client | kubectl apply -f -)

}

function ccloud::schema-registry::apply_secret_for_endpoint() {
  local environment_name
  local "${@}"

  local sr_description=$(ccloud schema-registry cluster describe -o json)
  local endpoint=$(echo $sr_description | jq -r '.endpoint_url')

  local secret_name="cc.schema-registry-url.$environment_name"

  local result=$(kubectl create secret generic $secret_name --from-literal="schema-registry-url.properties"="schema.registry.url=$endpoint" -o yaml --dry-run=client | kubectl apply -f -)
  echo $result
  
}
