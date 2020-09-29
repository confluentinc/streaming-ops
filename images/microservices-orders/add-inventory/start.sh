#!/bin/bash

for f in /etc/config/add-inventory/*.properties; do (cat "${f}"; echo) >> /etc/config/add-inventory/add-inventory.properties; done

CONFIG_FILE=${CONFIG_FILE:-/etc/config/add-inventory/add-inventory.properties}

BOOTSTRAP_SERVERS=$(grep "bootstrap.servers" $CONFIG_FILE | cut -d= -f2)
SCHEMA_REGISTRY_URL=$(grep "schema.registry.url" $CONFIG_FILE | cut -d= -f2)
RESTPORT=${RESTPORT:-18894}
JAR=${JAR:-"/usr/share/java/kafka-streams-examples/kafka-streams-examples-6.0.0-standalone.jar"}
CONFIG_FILE_ARG="--config-file $CONFIG_FILE"
ADDITIONAL_ARGS=${ADDITIONAL_ARGS:-""}

echo "starting add-inventory"
env

java -cp $JAR io.confluent.examples.streams.microservices.AddInventory --bootstrap-servers $BOOTSTRAP_SERVERS $CONFIG_FILE_ARG $ADDITIONAL_ARGS

