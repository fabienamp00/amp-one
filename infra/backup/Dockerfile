FROM alpine:3.20
RUN apk add --no-cache bash curl postgresql16-client zstd
COPY run.sh /run.sh
ENTRYPOINT ["/run.sh"]