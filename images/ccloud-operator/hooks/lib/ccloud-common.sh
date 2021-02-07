# include guard
if [ -n "$LIB_CCLOUD_COMMON" ]; then return; fi
LIB_CCLOUD_COMMON=`date`

function ccloud::login() {
	ccloud login --save
}

function ccloud::save_cloud_key() {

  local current_cloud_key=$(kubectl get secrets/cc.api-key.cloud -o json | jq -c -r '.data.key' | base64 -d)
  ccloud api-key delete "$current_cloud_key"

  local new_cloud_key=$(ccloud api-key create --resource cloud -o json --description "cc.api-key.cloud")
  local key=$(echo $new_cloud_key | jq -r -c ".key")
  local secret=$(echo $new_cloud_key | jq -r -c ".secret")
  kubectl create secret generic cc.api-key.cloud --from-literal="key"="$key" --from-literal="secret"="$secret" -o yaml --dry-run=client | kubectl apply -f -

}
