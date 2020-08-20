if [ -n "$LIB_CCLOUD_SR" ]; then return; fi
LIB_CCLOUD_ENV=`date`

source $SHELL_OPERATOR_HOOKS_DIR/lib/ccloud-kafka.sh

####################################################################
# Apply an schema-registry configuration given in json as the
# first parameter
####################################################################
function ccloud::schema-registry::apply() {
  cloud=$(echo $1 | jq -r .cloud)
  geo=$(echo $1 | jq -r .geo)	
  result=$(ccloud schema-registry cluster enable --cloud "$cloud" --geo "$geo" -o json)
  echo $result | jq -r '.id'
}

