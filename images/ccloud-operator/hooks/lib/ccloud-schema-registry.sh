if [ -n "$LIB_CCLOUD_SR" ]; then return; fi
LIB_CCLOUD_ENV=`date`

source $SHELL_OPERATOR_HOOKS_DIR/lib/ccloud-kafka.sh

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

  local secret_result=$(ccloud::schema-registry::apply_secret_for_endpoint environment_name="$environment_name") && {
    echo $result | jq -r '.id'
  } || {
    local ret_code=$?
    echo "error creating schema-registry secret: $secret_result"
    return $ret_code
  }
}

function ccloud::schema-registry::apply_secret_for_endpoint() {
  local environment_name
  local "${@}"

  local sr_description=$(ccloud schema-registry cluster describe -o json)
  local endpoint=$(echo $sr_description | jq -r '.endpoint_url')

  local result=$(kubectl create secret generic "cc.sr.$environment_name" --from-literal="schema.registry.url.properties"="schema.registry.url=$endpoint" -o yaml --dry-run=client | kubectl apply -f -)
  echo $result
  
}
