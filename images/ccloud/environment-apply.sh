#!/bin/sh

ccloud login > /dev/null 2>&1
FOUND_ENVIRONMENT=$(ccloud environment list -o json | jq -c -r '.[] | select(.name=="'"$@"'")')
FOUND_COUNT=$(echo $FOUND_ENVIRONMENT | sed '/^[[:space:]]*$/d' | wc -l)
[[ $FOUND_COUNT -eq 1 ]] && {
		>&2 echo "environment $@ exists, no action taken"
  } || {
		ccloud environment create "$@"
  }

