FROM alpine:3.19

ARG MKCERT_VERSION=1.4.4
ARG MKCERT_SHA256=8840ae6c5718262442d0912dce6e7b365ddfd00563d1767c9de10e7198d9e48d

RUN apk add --no-cache nss-tools ca-certificates openssl curl \
    && update-ca-certificates \
    && curl -fsSL "https://github.com/FiloSottile/mkcert/releases/download/v${MKCERT_VERSION}/mkcert-v${MKCERT_VERSION}-linux-amd64" -o /usr/local/bin/mkcert \
    && echo "${MKCERT_SHA256}  /usr/local/bin/mkcert" | sha256sum -c - \
    && chmod +x /usr/local/bin/mkcert

ENV CERT_DIR=/certs \
    CA_DIR=/certs \
    MKCERT_HOSTNAMES="localhost 127.0.0.1 ::1 mysql api-manager is-as-km"

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

VOLUME ["/certs"]

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]
