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
#       (not currently supported)
#
##############################################################

source $SHELL_OPERATOR_HOOKS_DIR/lib/common.sh
source $SHELL_OPERATOR_HOOKS_DIR/lib/ccloud-common.sh
source $SHELL_OPERATOR_HOOKS_DIR/lib/ccloud-service-account.sh
source $SHELL_OPERATOR_HOOKS_DIR/lib/ccloud-environment.sh

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
	echo "!! Deleting resources with ccloud-operator is not supported at this time. To delete resources use the ccloud CLI or Confluent Cloud web UI.  See: https://github.com/confluentinc/streaming-ops/issues/3"
}

hook::run() {
	ccloud::login
  ccloud::save_cloud_key

  # shell-operator gives us a wrapper around the resource we are monitoring
  # in a file located at the path of $BINDING_CONTEXT_PATH
  # The data model for this object can be found here:
  # https://github.com/flant/shell-operator/blob/master/pkg/hook/binding_context/binding_context.go

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

