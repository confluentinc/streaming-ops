#!/bin/bash

STARTUP_DELAY=${STARTUP_DELAY:-0}

for f in /etc/config/fraud-service/*.properties; do (cat "${f}"; echo) >> /etc/config/fraud-service/fraud-service.properties; done

CONFIG_FILE=${CONFIG_FILE:-/etc/config/fraud-service/fraud-service.properties}

BOOTSTRAP_SERVERS=$(grep "bootstrap.servers" $CONFIG_FILE | cut -d= -f2)
SCHEMA_REGISTRY_URL=$(grep "schema.registry.url" $CONFIG_FILE | cut -d= -f2)
RESTPORT=${RESTPORT:-18894}
JAR=${JAR:-"/usr/share/java/kafka-streams-examples/kafka-streams-examples-6.0.0-standalone.jar"}
CONFIG_FILE_ARG="--config-file $CONFIG_FILE"
ADDITIONAL_ARGS=${ADDITIONAL_ARGS:-""}

echo "starting fraud-service"
env

sleep $STARTUP_DELAY

java -cp $JAR io.confluent.examples.streams.microservices.FraudService --bootstrap-servers $BOOTSTRAP_SERVERS --schema-registry $SCHEMA_REGISTRY_URL $CONFIG_FILE_ARG $ADDITIONAL_ARGS

