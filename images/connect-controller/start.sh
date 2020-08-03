#!/bin/bash

: "${CONNECTORS_PATH?Need to set CONNECTORS_PATH}"

FILES="$CONNECTORS_PATH/*.json"
for f in $FILES
do
  echo $f
done
