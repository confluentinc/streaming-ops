FROM confluentinc/cp-server-connect:5.5.1

RUN confluent-hub install --no-prompt confluentinc/kafka-connect-jdbc:5.5.1
RUN confluent-hub install --no-prompt confluentinc/kafka-connect-elasticsearch:5.5.1

ADD start.sh /opt/docker/start.sh

ENTRYPOINT [ "/opt/docker/start.sh" ]
