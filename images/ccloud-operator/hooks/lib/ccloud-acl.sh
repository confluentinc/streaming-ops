if [ -n "$LIB_CCLOUD_ACL" ]; then return; fi
LIB_CCLOUD_ACL=`date`

source $SHELL_OPERATOR_HOOKS_DIR/lib/common.sh
source $SHELL_OPERATOR_HOOKS_DIR/lib/ccloud-service-account.sh

function ccloud::acl::apply_list() {
	local kafka_id acl
	local "${@}"

	for ACL_ENCODED in $(echo $acl | jq -c -r '.[] | @base64'); do

		local ACL=$(echo "${ACL_ENCODED}" | base64 -d)

		local service_account=$(echo $ACL | jq -r '."service-account"')

    for CONTROL_ENCODED in $(echo $ACL | jq -r -c '.controls | .[] | @base64'); do
      local control=$(echo "${CONTROL_ENCODED}" | base64 -d)

		  local permission=$(echo $control | jq -r '.permission')
      local resource=$(echo $control | jq -r '.resource')
      local name=$(echo $control | jq -r '.name')
      local prefix=$(echo $control | jq -r '.prefix')
		  local operation=$(echo $control | jq -r '.operation')

      if [ "$resource" == "topic" ]; then
		    ccloud::acl::apply_topic kafka_id=$kafka_id permission=$permission service_account=$service_account operation=$operation topic=$name prefix=$prefix
      elif [ "$resource" == "consumer-group" ]; then
		    ccloud::acl::apply_consumer_group kafka_id=$kafka_id permission=$permission service_account=$service_account operation=$operation consumer_group=$name prefix=$prefix
      elif [ "$resource" == "cluster-scope" ]; then
		    ccloud::acl::apply_cluster_scope kafka_id=$kafka_id permission=$permission service_account=$service_account operation=$operation
      else
        echo "$resource acls not yet supported"
      fi
    done

	done
}

function ccloud::acl::apply_topic() {
  local kafka_id permission service_account operation topic prefix
  local "${@}"

  local sa_id=$(ccloud::sa::get_id name=$service_account)
  local permission_flag=$([[ $permission == "allow" ]] && echo "--allow" || echo "--deny")
  local service_account_flag="--service-account $sa_id"
  local prefix_flag=$( [[ "$prefix" != "true" ]] && echo "" || echo "--prefix" )

  PREV_IFS=$IFS
  IFS=","
  local operation_flag=""
  for o in $operation
  do
    operation_flag=$operation_flag" --operation $o"
  done
  IFS=$PREV_IFS

  local result=$(ccloud kafka acl create $permission_flag $service_account_flag $operation_flag --topic "$topic" --cluster $kafka_id -o json 2>&1) && {
    echo "configured acl: $service_account:$operation:topic:$topic:$prefix"
  } || {
    echo "error configuring acl: $service_account:$operation:topic:$topic:$prefix: $result"
  }
}

function ccloud::acl::apply_consumer_group() {
  local kafka_id permission service_account operation consumer_group prefix
  local "${@}"

  local sa_id=$(ccloud::sa::get_id name=$service_account)

  local permission_flag=$([[ $permission == "allow" ]] && echo "--allow" || echo "--deny")
  local service_account_flag="--service-account $sa_id"
  local consumer_group_flag="--consumer-group $consumer_group"
  local prefix_flag=$([[ $prefix == "null" ]] || [[ $prefix != "true" ]] && echo "" | echo "--prefix")

  PREV_IFS=$IFS
  IFS=","
  local operation_flag=""
  for o in $operation
  do
    operation_flag=$operation_flag" --operation $o"
  done
  IFS=$PREV_IFS

  local result=$(ccloud kafka acl create $permission_flag $service_account_flag $operation_flag $consumer_group_flag --cluster $kafka_id -o json 2>&1) && {
    echo "configured acl: $service_account:$operation:consumer-group:$consumer_group:$prefix"
  } || {
    echo "error configuring acl: $service_account:$operation:consumer-group:$consumer_group:$prefix: $result"
  }
}

function ccloud::acl::apply_cluster_scope() {
  local kafka_id permission service_account operation
  local "${@}"

  local sa_id=$(ccloud::sa::get_id name=$service_account)

  local permission_flag=$([[ $permission == "allow" ]] && echo "--allow" || echo "--deny")
  local service_account_flag="--service-account $sa_id"

  PREV_IFS=$IFS
  IFS=","
  local operation_flag=""
  for o in $operation
  do
    operation_flag=$operation_flag" --operation $o"
  done
  IFS=$PREV_IFS

  local result=$(ccloud kafka acl create $permission_flag $service_account_flag $operation_flag --cluster-scope --cluster $kafka_id -o json 2>&1) && {
    echo "configured acl: $service_account:$operation:cluster-scope"
  } || {
    echo "error configuring acl: $service_account:$operation:cluster-scope: $result"
  }
}
