FROM alpine:3.19

RUN apk add --no-cache mkcert nss-tools ca-certificates openssl \
    && update-ca-certificates

ENV CERT_DIR=/certs \
    CA_DIR=/certs \
    MKCERT_HOSTNAMES="localhost 127.0.0.1 ::1 mysql api-manager is-as-km"

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

VOLUME ["/certs"]

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]
