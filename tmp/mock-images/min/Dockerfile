FROM alpine:3.13.2

RUN apk add --no-cache curl bash jq

COPY wait_for.sh wait_for.sh

ENTRYPOINT ["/bin/bash"]
