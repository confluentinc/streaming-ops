FROM alpine:3.12.0

RUN apk --no-cache add jq curl kafkacat

RUN wget https://github.com/mikefarah/yq/releases/download/3.3.2/yq_linux_amd64 && install -m 755 yq_linux_amd64 /usr/local/bin/yq && rm -f yq_linux_amd64

ENTRYPOINT ["sh"]
