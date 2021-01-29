if [ -n "$LIB_CCLOUD_ENV" ]; then return; fi
LIB_CCLOUD_ENV=`date`

source $SHELL_OPERATOR_HOOKS_DIR/lib/ccloud-kafka.sh
source $SHELL_OPERATOR_HOOKS_DIR/lib/ccloud-schema-registry.sh

function ccloud::env::apply_list() {
  for ENV_ENCODED in $(echo $1 | jq -c -r '.[] | @base64'); do

    local ENV=$(echo "${ENV_ENCODED}" | base64 -d)

    local envname=$(echo $ENV | jq -r .name)
    local env_id=$(ccloud::env::apply name="$envname")

    if [[ $? -eq 0 ]]; then
      echo "configured environment: $envname, id = $env_id"

      ccloud environment use "$env_id"

      local KAFKA=$(echo $ENV | jq -r -c '.kafka')
      ccloud::kafka::apply_list kafka="$KAFKA" environment_name="$envname"

      local SR=$(echo $ENV | jq -r -c '."schema-registry"')
      local sr_id=$(ccloud::schema-registry::apply sr="$SR" environment_name="$envname")
      echo "configured schema-registry: $sr_id"
    else
      echo "Error $? applying environment: $envname, $env_id"
    fi

  done
}

####################################################################
# Apply an environment configuration with the named parameters;
# name
####################################################################
function ccloud::env::apply() {
  local name
  local "${@}"
  local env_id=""
  local result=""
  local retcode=1
  result=$(ccloud environment create $name -o json 2>&1)
  retcode=$?
  if [[ $retcode -eq 0 ]]; then
    env_id=$(echo $result | jq -r '.id')
    ccloud::env::apply_env_id_configmap name="$name" id="$env_id"
    echo $env_id
  elif [[ "$result" == *"already in use"* ]]; then
    env_id=$(ccloud environment list -o json | jq -r '.[] | select(.name=="'"$name"'") | .id')
    ccloud::env::apply_env_id_configmap name="$name" id="$env_id"
    echo $env_id
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

##################################
# Apply a k8s ConfigMap to the
# current env with a given
# Confluent Cloud environment Name
# and ID
##################################
function ccloud::env::apply_env_id_configmap() {
  local name
  local id
  local "${@}"
  kubectl create configmap "cc.env.$name" --from-literal="id"="$id" --dry-run=client -o yaml | kubectl label -f - --dry-run=client -o yaml --local resource_id=$id | kubectl apply -f - >/dev/null 2>&1
}
