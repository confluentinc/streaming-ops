# include guard
if [ -n "$LIB_CCLOUD_COMMON" ]; then return; fi
LIB_CCLOUD_COMMON=`date`

function ccloud::login() {
	ccloud login --save
}

function ccloud::save_cloud_key() {

  kubectl get secrets/cc.api-key.cloud > /dev/null 2>&1 || {
    # todo: rotating keys needs work as it depends on how pods are updated dynamically with the new values.  Investigate
    #   for now, just don't change existing key, a user could delete a key and this will create a new one

    local new_cloud_key=$(ccloud api-key create --resource cloud -o json --description "cc.api-key.cloud")
    local key=$(echo $new_cloud_key | jq -r -c ".key")
    local secret=$(echo $new_cloud_key | jq -r -c ".secret")
    kubectl create secret generic cc.api-key.cloud --from-literal="key"="$key" --from-literal="secret"="$secret" -o yaml --dry-run=client | kubectl apply -f -
  }
}
