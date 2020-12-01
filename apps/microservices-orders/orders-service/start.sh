#!/bin/sh

STARTUP_DELAY=${STARTUP_DELAY:-0}

sleep $STARTUP_DELAY

java -jar /app/orders-service-*.jar "$@"

