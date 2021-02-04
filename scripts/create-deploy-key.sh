#!/bin/bash

: "${GH_TOKEN?Need to set GH_TOKEN with your personal access token}"
: "${KEY?Need to set KEY with the deploy key you wish to create in the repository}"
: "${NAME?Need to set NAME with the deploy key name you wish to create in the repository}"
: "${ORG?Need to set ORG with the GitHub organization of the repository}"

USERNAME=${USERNAME:-$(whoami)}

DATA=$(jq -n --arg title "$NAME" --arg key "$KEY" --arg read_only "false" '{title: $title, key: $key, read_only: $read_only}')

echo "Posting new GH Deploy key"
curl -XPOST -u$USERNAME:$GH_TOKEN https://api.github.com/repos/$ORG/streaming-ops/keys -d "$DATA"

