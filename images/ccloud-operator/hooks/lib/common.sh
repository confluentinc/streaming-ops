# include guard
if [ -n "$LIB_COMMON" ]; then return; fi
LIB_COMMON=`date`

common::get_config() {
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
}

common::run_hook() {
  if [[ $1 == "--config" ]] ; then
    common::get_config
  else
    hook::run
  fi
}

