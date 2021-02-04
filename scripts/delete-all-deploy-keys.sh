#!/bin/bash

: "${GH_TOKEN?Need to set GH_TOKEN with your personal access token}"

USERNAME=${USERNAME:-$(whoami)}
ORG=${ORG:-"confluentinc"}

CURRENT_KEYS=$(curl -s -XGET -u$USERNAME:$GH_TOKEN https://api.github.com/repos/$ORG/streaming-ops/keys)
for id in $(echo $CURRENT_KEYS | jq -c -r '.[].id'); do
	echo "deleting $id"
	curl -s -XDELETE -u$USERNAME:$GH_TOKEN https://api.github.com/repos/$ORG/streaming-ops/keys/$id
done
