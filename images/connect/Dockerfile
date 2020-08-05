FROM confluentinc/cp-server-connect:5.5.1

RUN confluent-hub install --no-prompt confluentinc/kafka-connect-jdbc:5.5.1
RUN confluent-hub install --no-prompt confluentinc/kafka-connect-elasticsearch:5.5.1

RUN wget https://repo1.maven.org/maven2/mysql/mysql-connector-java/8.0.21/mysql-connector-java-8.0.21.jar -P /usr/share/java/kafka-connect-jdbc/

ADD start.sh /opt/docker/start.sh

ENTRYPOINT [ "/opt/docker/start.sh" ]
