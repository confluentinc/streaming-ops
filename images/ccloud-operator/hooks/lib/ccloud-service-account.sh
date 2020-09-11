if [ -n "$LIB_CCLOUD_SA" ]; then return; fi
LIB_CCLOUD_SA=`date`

source $SHELL_OPERATOR_HOOKS_DIR/lib/ccloud-common.sh

####################################################################
# Apply a *json array* of service accounts to the configured ccloud,
# passed in arg 2.
# The data model of what this function expects is
# in the Service Account ConfigMap
####################################################################
function ccloud::sa::apply_list() {
	# we encode, then decode, the list into base64 so that we can
	# iterate over them using a bash for loop, otherwise the spaces
	# would break up the loop elements
	for SA_ENCODED in $(echo $1 | jq -c -r '.[] | @base64'); do
		SA=$(echo "${SA_ENCODED}" | base64 -d)
		local svcacctname=$(echo $SA | jq -r .name)
		local svcacctdesc=$(echo $SA | jq -r .description)
		local sa_id=$(ccloud::sa::apply name="$svcacctname" description="$svcacctdesc")
		echo "configured service-account: $svcacctname, id = $sa_id"
	done
}

####################################################################
# Apply a service account configuration with the named parameters;
# name
# description
####################################################################
function ccloud::sa::apply() {
	local name description
	local "${@}"
	result=$(ccloud service-account create $name --description "$description" -o json 2>&1)
	retcode=$?
	if [[ $retcode -eq 0 ]]; then
		echo $result | jq -r '.id'
	elif [[ "$result" == *"already in use"* ]]; then
		ccloud service-account list -o json | jq -r '.[] | select(.name=="'"$name"'") | .id'
	else
		echo $result
		return $retcode
	fi
}

function ccloud::sa::get_id() {
  local name
  local "${@}"
	ccloud service-account list -o json | jq -r '.[] | select(.name=="'"$name"'") | .id'
}

##################################
# Delete a given service account
# name to the configured ccloud
##################################
function ccloud::sa::delete() {
	local id
	local "${@}"
	ccloud service-account delete "$id"
}
