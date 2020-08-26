#!/usr/bin/env bash

##############################################################
# A shell-operator (https://github.com/flant/shell-operator)
# to manage Confluent Cloud (https://confluent.cloud/)
# resources using an Operator style pattern with standard
# K8s resources (ConfigMaps, Secrets, etc...)
# 
# Shell operators have 3 stages
#   1. Synchronize on startup
#   2. Apply when the monitored resources change
#   3. Delete when the monitored resources are deleted
#
##############################################################

source $SHELL_OPERATOR_HOOKS_DIR/lib/common.sh
source $SHELL_OPERATOR_HOOKS_DIR/lib/ccloud-common.sh
source $SHELL_OPERATOR_HOOKS_DIR/lib/ccloud-service-account.sh
source $SHELL_OPERATOR_HOOKS_DIR/lib/ccloud-environment.sh

# By default Deleting of resources will be disabled
#DELETE_ENABLED=${DELETE_ENABLED:-"false"}

hook::synchronize() {

  DATA="$1"

  SVC_ACCOUNTS=$(echo $DATA | jq -r '."service-accounts"')
  ccloud::sa::apply_list "$SVC_ACCOUNTS"

  ENVIRONMENTS=$(echo $DATA | jq -r '.environments')
	ccloud::env::apply_list "$ENVIRONMENTS"

}

hook::apply() {
	hook::synchronize "$1"
}

hook::delete() {
	echo "!! Deleting resources with ccloud-operator is not supported at this time. See: https://github.com/confluentinc/kafka-devops/issues/3"

	# if deleting is supported, some type of toggle should be used and heavy warnings implemented 
	#if [[ "$DELETE_ENABLED" == "true" ]]; then
  #	DATA=$(jq -c -r ".[$INDEX].object.data" $BINDING_CONTEXT_PATH)
	#	echo "!! Delete is enabled, proceeding to delete ccloud resources"
	#else 
	#	echo "!! Warning: Operator resources have been deleted, but DELETE_ENABLED is not true"
	#fi

  #DATA=$(jq -c -r ".[$INDEX].object.data" $BINDING_CONTEXT_PATH)
  #echo $DATA

}

hook::run() {
	ccloud::login
  ARRAY_COUNT=`jq -r '. | length-1' $BINDING_CONTEXT_PATH`
  for I in `seq 0 $ARRAY_COUNT`
  do
    export INDEX=$I
    TYPE=$(jq -r ".[$INDEX].type" $BINDING_CONTEXT_PATH)
    if [[ "$TYPE" == "Synchronization" ]]; then
      d=$(jq -c ".[$INDEX].objects | .[].object.data" $BINDING_CONTEXT_PATH)
      hook::synchronize "$d" 
    elif [[ "$TYPE" == "Event" ]]; then
      EVENT=$(jq -r ".[$INDEX].watchEvent" $BINDING_CONTEXT_PATH)
      if [[ "$EVENT" == "Deleted" ]]; then
        d=$(jq -c -r ".[$INDEX].object.data" $BINDING_CONTEXT_PATH)
        hook::delete "$d"
      else
        d=$(jq -c -r ".[$INDEX].object.data" $BINDING_CONTEXT_PATH)
        hook::apply "$d"
      fi
    fi
  done
}

common::run_hook "$@"

