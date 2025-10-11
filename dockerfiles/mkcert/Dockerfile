FROM alpine:3.19

ENV MKCERT_VERSION=1.4.4

RUN apk add --no-cache curl nss-tools ca-certificates openssl \
    && update-ca-certificates \
    && curl -sSLo /usr/local/bin/mkcert "https://github.com/FiloSottile/mkcert/releases/download/v${MKCERT_VERSION}/mkcert-v${MKCERT_VERSION}-linux-amd64" \
    && chmod +x /usr/local/bin/mkcert

ENV CERT_DIR=/certs \
    CA_DIR=/certs \
    MKCERT_HOSTNAMES="localhost 127.0.0.1 ::1 mysql api-manager is-as-km"

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

VOLUME ["/certs"]

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]
