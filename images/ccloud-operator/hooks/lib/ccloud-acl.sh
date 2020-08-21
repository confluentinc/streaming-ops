if [ -n "$LIB_CCLOUD_ACL" ]; then return; fi
LIB_CCLOUD_ACL=`date`

source $SHELL_OPERATOR_HOOKS_DIR/lib/common.sh

function ccloud::acl::apply_list() {
	local kafka_id acls
	local "${@}"

	for ACL_ENCODED in $(echo $acls | jq -c -r '.[] | @base64'); do
		
		ACL=$(echo "${ACL_ENCODED}" | base64 --decode)

		local service_account=$(echo $ACL | jq -r '."service-account"')
		local operation=$(echo $ACL | jq -r .operation)
		local permission=$(echo $ACL | jq -r .permission)
    local resource=$(echo $ACL | jq -r .resource)
    local name=$(echo $ACL | jq -r .name)
    local prefix=$(echo $ACL | jq -r .prefix)

    if [[ "$resource" == "topic" ]]; then
		  ccloud::acl::apply_topic kafka_id="$kafka_id" permission="$permission" service_account="$service_account" operation="$operation" topic="$name" prefix="$prefix"  
    else 
      echo "$resource acls not yet supported"
    fi

	done
}

function ccloud::acl::apply_topic() {
  local kafka_id permission service_account operation topic prefix
  local "${@}"

  local permission_flag=$([[ $permission == "allow" ]] && echo "--allow" || echo "--deny")
  local service_account_flag="--service-account $service_account"
  local operation_flag="--operation $operation"
  local topic_flag="--topic \"$topic\"" 
  local prefix_flag=$([[ $prefix == "null" ]] && echo "" | echo "--prefix") 

  echo "ccloud acl create $permission_flag $service_account_flag $operation_flag $topic_flag --cluster $kafka_id"
}

