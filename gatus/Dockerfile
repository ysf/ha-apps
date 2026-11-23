FROM ghcr.io/twin/gatus:v5.38.0 AS gatus

FROM alpine:3.22
RUN apk add --no-cache ca-certificates curl jq
COPY --from=gatus /gatus /usr/local/bin/gatus
COPY run.sh /run.sh
RUN chmod +x /run.sh
CMD ["/run.sh"]
