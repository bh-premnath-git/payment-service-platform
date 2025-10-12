#!/bin/sh
set -eu

CERT_DIR="${CERT_DIR:-/certs}"
CA_DIR="${CA_DIR:-${CERT_DIR}}"
HOSTNAMES="${MKCERT_HOSTNAMES:-}" 

mkdir -p "${CERT_DIR}"
mkdir -p "${CA_DIR}"
mkdir -p /root/.local/share/mkcert

CA_PEM="${CA_DIR%/}/rootCA.pem"
CA_KEY="${CA_DIR%/}/rootCA-key.pem"

if [ -f "${CA_PEM}" ] && [ -f "${CA_KEY}" ]; then
  cp "${CA_PEM}" /root/.local/share/mkcert/rootCA.pem
  cp "${CA_KEY}" /root/.local/share/mkcert/rootCA-key.pem
else
  mkcert -install >/dev/null 2>&1
  cp /root/.local/share/mkcert/rootCA.pem "${CA_PEM}"
  cp /root/.local/share/mkcert/rootCA-key.pem "${CA_KEY}"
fi

CERT_FILE="${CERT_DIR%/}/cert.pem"
KEY_FILE="${CERT_DIR%/}/key.pem"

if [ -n "${HOSTNAMES}" ]; then
  set -- ${HOSTNAMES}
else
  set -- localhost 127.0.0.1 ::1
fi

if [ ! -f "${CERT_FILE}" ] || [ ! -f "${KEY_FILE}" ]; then
  mkcert -cert-file "${CERT_FILE}" -key-file "${KEY_FILE}" "$@"
fi

if [ "${MKCERT_EXPORT_PKCS12:-false}" = "true" ]; then
  PKCS12_FILE="${CERT_DIR%/}/cert.p12"
  if [ ! -f "${PKCS12_FILE}" ]; then
    openssl pkcs12 -export \
      -inkey "${KEY_FILE}" \
      -in "${CERT_FILE}" \
      -out "${PKCS12_FILE}" \
      -passout pass:${MKCERT_PKCS12_PASSWORD:-changeit}
  fi
fi

exec "$@"
