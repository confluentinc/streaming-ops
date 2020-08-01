#!/bin/bash

: "${TOKEN?Need to set TOKEN with your personal access token}"
: "${KEY?Need to set KEY with the deploy key you wish to create in the repository}"
: "${NAME?Need to set NAME with the deploy key name you wish to create in the repository}"

USERNAME=${USERNAME:-$(whoami)}
ORG=${ORG:-"confluentinc"}

DATA=$(jq -n --arg title "$NAME" --arg key "$KEY" --arg read_only "false" '{title: $title, key: $key, read_only: $read_only}')

curl -XPOST -u$USERNAME:$TOKEN https://api.github.com/repos/$ORG/kafka-devops/keys -d "$DATA"
