#!/usr/bin/env bash

source $SHELL_OPERATOR_HOOKS_DIR/lib/common.sh
source $SHELL_OPERATOR_HOOKS_DIR/lib/ccloud-common.sh
source $SHELL_OPERATOR_HOOKS_DIR/lib/ccloud-service-account.sh

hook::synchronize() {

  DATA=$(jq -c ".[$INDEX].objects | .[].object.data" $BINDING_CONTEXT_PATH)

  SVC_ACCOUNTS=$(echo $DATA | jq '."service-accounts"')
  ccloud::sa::apply_list "$SVC_ACCOUNTS"

  ENVIRONMENTS=$(echo $DATA | jq '.environments')
  #echo $ENVIRONMENTS

}
hook::apply() {
  DATA=$(jq -c -r ".[$INDEX].object.data" $BINDING_CONTEXT_PATH)
}
hook::delete() {
  DATA=$(jq -c -r ".[$INDEX].object.data" $BINDING_CONTEXT_PATH)
}

hook::run() {
	ccloud::login
  ARRAY_COUNT=`jq -r '. | length-1' $BINDING_CONTEXT_PATH`
  for I in `seq 0 $ARRAY_COUNT`
  do
    export INDEX=$I
    TYPE=$(jq -r ".[$INDEX].type" $BINDING_CONTEXT_PATH)
    if [[ "$TYPE" == "Synchronization" ]]; then
      hook::synchronize
    elif [[ "$TYPE" == "Event" ]]; then
      EVENT=$(jq -r ".[$INDEX].watchEvent" $BINDING_CONTEXT_PATH)
      if [[ "$EVENT" == "Deleted" ]]; then
        hook::delete
      else
        hook::apply
      fi
    fi
  done
}

common::run_hook "$@"
