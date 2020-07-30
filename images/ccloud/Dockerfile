FROM alpine:3.7
RUN apk --no-cache add curl jq
WORKDIR /opt/ccloud
RUN curl -s -L --http1.1 https://cnfl.io/ccloud-cli | sh -s -- v1.14.0
ENV PATH "$PATH:/opt/ccloud/bin"
ADD *.sh /opt/ccloud/bin/

