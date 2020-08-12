FROM flant/shell-operator:v1.0.0-beta.11-alpine3.9
RUN apk --no-cache add curl
RUN curl -L --http1.1 https://cnfl.io/ccloud-cli | sh -s -- -b /usr/bin v1.14.0
ADD hooks /hooks
