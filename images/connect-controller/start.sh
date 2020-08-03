#!/bin/bash

: "${CONNECTORS_PATH?Need to set CONNECTORS_PATH}"

for FILE in $CONNECTORS_PATH;
do
  echo "connector found----"
  cat $FILE;
done
