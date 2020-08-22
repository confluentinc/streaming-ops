# include guard
if [ -n "$LIB_COMMON" ]; then return; fi
LIB_COMMON=`date`

UNKNOWN_ERROR=1
SERVICE_ACCOUNT_NOT_FOUND=2
CCLOUD_ERROR=3
KUBE_ERROR=4

function retry() {
    local -r -i max_wait="$1"; shift
    local -r cmd="$@"

    local -i sleep_interval=5
    local -i curr_wait=0

    until $cmd
    do
        if (( curr_wait >= max_wait ))
        then
            echo "ERROR: Failed after $curr_wait seconds. Please troubleshoot and run again."
            return 1
        else
            curr_wait=$((curr_wait+sleep_interval))
            sleep $sleep_interval
        fi
    done
}

function common::get_config() {
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

function common::run_hook() {
  if [[ $1 == "--config" ]] ; then
    common::get_config
  else
    hook::run
  fi
}

