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
  echo "got $ARRAY_COUNT items in binding, looking at first"

  TYPE=$(jq -r .[0].type $BINDING_CONTEXT_PATH)
  EVENT=$(jq -r .[0].watchEvent $BINDING_CONTEXT_PATH)

  if [[ "$TYPE" == "Synchronization" ]]; then
    #KEYS=$(jq -c -r '.[0].objects | .[].object.data | keys | .[]' $BINDING_CONTEXT_PATH)
		#for KEY in $KEYS; do
		#	CONFIG=$(jq -c -r ".[].objects | .[].object.data | select(has(\"$KEY\")) | .\"$KEY\"" $BINDING_CONTEXT_PATH)
		#done	
    echo "Got synchronization event"
    exit 0
  elif [[ "$TYPE" == "Event" ]]; then
    DATA=$(jq -r '.[0].object.data' $BINDING_CONTEXT_PATH)
    KEY=$(echo $DATA | jq -r -c 'keys | .[0]')
    CONFIG=$(echo $DATA | jq -r -c ".\"$KEY\"")
    if [[ "$EVENT" == "Deleted" ]]; then
      echo "delete"
    else
      echo "apply"
    fi
  fi
fi

