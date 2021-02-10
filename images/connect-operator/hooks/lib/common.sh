# include guard
if [ -n "$LIB_COMMON" ]; then return; fi
LIB_COMMON=`date`

function common::get_config() {
  cat <<EOF
configVersion: v1
kubernetes:
- name: ConnectConfigMapMonitor
  apiVersion: v1
  kind: ConfigMap
  executeHookOnEvent: ["Added","Deleted","Modified"]
  jqFilter: ".data"
  labelSelector:
    matchLabels:
      destination: connect
  namespace:
    nameSelector:
      matchNames: ["default"]
- name: ConnectStatusMonitor
  apiVersion: v1
  kind: ConfigMap
  executeHookOnEvent: ["Added","Deleted","Modified"]
  jqFilter: ".metadata.labels.enabled"
  labelSelector:
    matchLabels:
      destination: connect
  namespace:
    nameSelector:
      matchNames: ["default"]
EOF
}

function common::run_hook() {
  if [[ $1 == "--config" ]] ; then
    common::get_config
  else
    echo "common::run_hook"
    hook::run
  fi
}
