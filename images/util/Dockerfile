FROM alpine:3.12.0

ADD start.sh /opt/docker/start.sh

RUN apk --no-cache add jq curl kafkacat bash git make mariadb-client

RUN wget https://github.com/mikefarah/yq/releases/download/3.3.2/yq_linux_amd64 && install -m 755 yq_linux_amd64 /usr/local/bin/yq && rm -f yq_linux_amd64

RUN curl -sL https://storage.googleapis.com/kubernetes-release/release/v1.18.6/bin/linux/amd64/kubectl \
-o /usr/local/bin/kubectl && chmod +x /usr/local/bin/kubectl

ENTRYPOINT ["/opt/docker/start.sh"]
