if [ -n "$LIB_CCLOUD_SA" ]; then return; fi
LIB_CCLOUD_SA=`date`

source $SHELL_OPERATOR_HOOKS_DIR/lib/ccloud-common.sh

##################################
# Apply a given *yaml list* of 
# service accounts to the 
# configured ccloud. The data model
# of what this function expects is
# in the Service Account ConfigMap
##################################
function ccloud::sa::apply() {
  local service_account_data=$(echo $1 | yq r - .)
	#echo $service_account_data
	for SA_ENCODED in $(echo "$service_account_data" | jq -r '.[] | @base64'); do
		SA=$(echo "${SA_ENCODED}" | base64 --decode)
		local svcacctname=$(echo $SA | jq -r .name)
		local svcacctdesc=$(echo $SA | jq -r .description)
		ccloud::sa::create name="$svcacctname" description="$svcacctdesc"
	done
}

##################################
# Create a given service account
# name to the configured ccloud 
##################################
function ccloud::sa::create() {
	local name description
	local "${@}"
	ccloud service-account create $name --description "$description" || true
}
##################################
# Delete a given service account
# name to the configured ccloud 
##################################
function ccloud::sa::delete() {
  echo "hello from ccloud::sa::delete $1"
}
