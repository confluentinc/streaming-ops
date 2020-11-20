#!/bin/sh

STARTUP_DELAY=${STARTUP_DELAY:-0}

mkdir -p config

# The deployment mechanims might give us many properties files,
#   one for each secret for example.  We want to pass the orders-service app
#   a single properties file, so this bit will aggregate all the properties
#   files into one, in a well known place Spring looks.
#   Note: the application.properties name appears to be significant and has
#     different behavior than if you override the spring.config.location setting
[ -d "/etc/config/orders-service/" ] && {
  for f in /etc/config/orders-service/*.properties; do (cat "${f}"; echo) >> config/application.properties; done
}

# Spring Kafka requires Kafka client properties to have a prefix, like the following:
#   spring.kafka.properties.sasl.jass.config
# This sed command will edit in place the properties file constructed above and prefix
#   all the lines with spring.kafka.properties, skipping the comment and blank lines
sed -i '/^#/b; /^$/b; s/^/spring.kafka.properties./;' config/application.properties

echo "starting orders-service"
cat config/application.properties 2>/dev/null

sleep $STARTUP_DELAY

java -jar /app/orders-service-*.jar

