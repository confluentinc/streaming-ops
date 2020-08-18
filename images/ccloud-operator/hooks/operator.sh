#!/usr/bin/env bash

if [[ $1 == "--config" ]]; then
  cat <<EOF
configVersion: v1
kubernetes:
- name: ConnectConfigMapMonitor
  apiVersion: v1
  kind: ConfigMap
  executeHookOnEvent: ["Added","Deleted","Modified"]
  labelSelector:
    matchLabels:
      destination: ccloud
  namespace:
    nameSelector:
      matchNames: ["default"]
  jqFilter: ".data"
EOF
else
  ARRAY_COUNT=`jq -r '. | length-1' $BINDING_CONTEXT_PATH`
  for I in `seq 0 $ARRAY_COUNT`
  do
    export INDEX=$I
    TYPE=$(jq -r ".[$INDEX].type" $BINDING_CONTEXT_PATH)
    if [[ "$TYPE" == "Synchronization" ]]; then
      DATA=$(jq -c ".[$INDEX].objects | .[].object.data" $BINDING_CONTEXT_PATH)
      SVC_ACCOUNTS=$(echo $DATA | jq -r '."service-accounts"' | yq r - '.name')
      echo $SVC_ACCOUNTS
      while IRS= read -r svcacct; do
        echo "ccloud service-account create $svcacct"
      done <<< $SVC_ACCOUNTS
    elif [[ "$TYPE" == "Event" ]]; then
      EVENT=$(jq -r ".[$INDEX].watchEvent" $BINDING_CONTEXT_PATH)
      DATA=$(jq -c -r ".[$INDEX].object.data" $BINDING_CONTEXT_PATH)
      #KEY=$(echo $DATA | jq -r -c 'keys | .[0]')
      #CONFIG=$(echo $DATA | jq -r -c ".\"$KEY\"")
      if [[ "$EVENT" == "Deleted" ]]; then
        echo "delete"
      else
        echo "apply"
      fi
    fi
    done
fi

