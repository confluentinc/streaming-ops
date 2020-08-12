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
  echo "hello from ccloud-operator"
fi

