FROM cnfldemos/kafka-streams-examples:5.5.1-DEVX-1881-PR346

RUN chown -R streams:streams /etc/config/orders-service
ADD start.sh /opt/docker/start.sh
ENTRYPOINT [ "/opt/docker/start.sh" ]
