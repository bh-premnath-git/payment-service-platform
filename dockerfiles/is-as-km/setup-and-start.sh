#!/bin/sh
set -eu

CERT_DIR="${CERT_DIR:-/certs}"
CONFIG_VOLUME="${CONFIG_VOLUME:-/home/wso2carbon/wso2-config-volume}"
SECURITY_DIR="${SECURITY_DIR:-${CONFIG_VOLUME%/}/repository/resources/security}"

ROOT_CA="${CERT_DIR%/}/rootCA.pem"
PKCS12_FILE="${CERT_DIR%/}/cert.p12"
PKCS12_PASSWORD="${MKCERT_PKCS12_PASSWORD:-changeit}"

KEYSTORE="${SECURITY_DIR%/}/wso2carbon.jks"
TRUSTSTORE="${SECURITY_DIR%/}/client-truststore.jks"
KEYSTORE_PASSWORD="${WSO2_KEYSTORE_PASSWORD:-wso2carbon}"
TRUSTSTORE_PASSWORD="${WSO2_TRUSTSTORE_PASSWORD:-wso2carbon}"
KEY_ALIAS="${WSO2_KEY_ALIAS:-wso2is}"
ROOT_ALIAS="${WSO2_ROOT_CA_ALIAS:-mkcert-root}"

log() {
  printf '%s\n' "$*"
}

maybe_import_root() {
  STORE="$1"
  PASSWORD="$2"
  if [ ! -f "${ROOT_CA}" ]; then
    log "[mkcert] Root CA ${ROOT_CA} not present; skipping import into ${STORE}."
    return 0
  fi

  if keytool -list -keystore "${STORE}" -storepass "${PASSWORD}" -alias "${ROOT_ALIAS}" >/dev/null 2>&1; then
    return 0
  fi

  keytool -importcert -trustcacerts -noprompt \
    -alias "${ROOT_ALIAS}" \
    -file "${ROOT_CA}" \
    -keystore "${STORE}" \
    -storepass "${PASSWORD}" >/dev/null
}

maybe_import_pkcs12() {
  if [ ! -f "${PKCS12_FILE}" ]; then
    log "[mkcert] Leaf PKCS12 bundle ${PKCS12_FILE} not present; skipping TLS key import."
    return 0
  fi

  SOURCE_ALIAS="$(keytool -list -keystore "${PKCS12_FILE}" -storetype PKCS12 -storepass "${PKCS12_PASSWORD}" 2>/dev/null | awk -F': ' '/Alias name:/ {print $2; exit}')"
  if [ -z "${SOURCE_ALIAS}" ]; then
    log "[mkcert] Unable to determine alias inside ${PKCS12_FILE}; skipping TLS key import."
    return 0
  fi

  keytool -delete -alias "${KEY_ALIAS}" -keystore "${KEYSTORE}" -storepass "${KEYSTORE_PASSWORD}" >/dev/null 2>&1 || true

  keytool -importkeystore -noprompt \
    -srckeystore "${PKCS12_FILE}" \
    -srcstoretype PKCS12 \
    -srcstorepass "${PKCS12_PASSWORD}" \
    -srcalias "${SOURCE_ALIAS}" \
    -destkeystore "${KEYSTORE}" \
    -deststoretype JKS \
    -deststorepass "${KEYSTORE_PASSWORD}" \
    -destkeypass "${KEYSTORE_PASSWORD}" \
    -destalias "${KEY_ALIAS}" >/dev/null
}

maybe_import_root "${TRUSTSTORE}" "${TRUSTSTORE_PASSWORD}"
maybe_import_root "${KEYSTORE}" "${KEYSTORE_PASSWORD}"
maybe_import_pkcs12

if [ -z "${WSO2_SERVER_HOME:-}" ]; then
  log "WSO2_SERVER_HOME is not set; defaulting to /home/wso2carbon/wso2is-7.1.0"
  WSO2_SERVER_HOME="/home/wso2carbon/wso2is-7.1.0"
fi

exec "${WSO2_SERVER_HOME}/bin/wso2server.sh"
