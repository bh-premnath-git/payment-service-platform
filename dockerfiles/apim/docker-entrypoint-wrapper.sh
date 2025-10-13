#!/bin/bash
set -e

echo "🔐 APIM Startup: Configuring SSL certificates..."

CLIENT_TRUSTSTORE="/home/wso2carbon/wso2am-4.5.0/repository/resources/security/client-truststore.p12"
INTERNAL_TRUSTSTORE="/home/wso2carbon/wso2am-4.5.0/repository/resources/security/truststore.p12"

# Wait for WSO2 IS to be available
echo "⏳ Waiting for WSO2 IS to be ready..."
MAX_RETRIES=30
RETRY_COUNT=0

until curl -k -s https://wso2is:9443/api/health-check/v1.0/health > /dev/null 2>&1; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo "❌ WSO2 IS failed to start within timeout"
        exit 1
    fi
    echo "   Waiting for WSO2 IS... ($RETRY_COUNT/$MAX_RETRIES)"
    sleep 5
done

echo "✅ WSO2 IS is ready"

# Function to import certificate into truststore
import_cert() {
    local truststore=$1
    local alias=$2
    
    if keytool -list -keystore "$truststore" -storepass wso2carbon -storetype PKCS12 -alias "$alias" 2>/dev/null | grep -q "$alias"; then
        echo "   ✅ Certificate already exists in $(basename $truststore)"
        return 0
    fi
    
    echo "   📥 Importing into $(basename $truststore)..."
    keytool -import -noprompt -alias "$alias" \
        -keystore "$truststore" \
        -storetype PKCS12 \
        -storepass wso2carbon \
        -file /tmp/wso2is.crt 2>&1 | grep -v "Warning" || true
}

# Export certificate from WSO2 IS
echo "📤 Fetching WSO2 IS certificate..."
echo | openssl s_client -connect wso2is:9443 2>/dev/null | \
    sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > /tmp/wso2is.crt

if [ ! -s /tmp/wso2is.crt ]; then
    echo "❌ Failed to fetch certificate from WSO2 IS"
    exit 1
fi

echo "📥 Importing certificate into APIM truststores..."
import_cert "$CLIENT_TRUSTSTORE" "wso2is"
import_cert "$INTERNAL_TRUSTSTORE" "wso2is"

# Clean up
rm -f /tmp/wso2is.crt

# Verify
echo "🔍 Verifying certificate imports..."
if keytool -list -keystore "$CLIENT_TRUSTSTORE" -storepass wso2carbon -storetype PKCS12 -alias wso2is 2>/dev/null | grep -q "trustedCertEntry"; then
    echo "   ✅ client-truststore.p12 verification successful"
else
    echo "   ⚠️  Warning: client-truststore.p12 verification failed"
fi

if keytool -list -keystore "$INTERNAL_TRUSTSTORE" -storepass wso2carbon -storetype PKCS12 -alias wso2is 2>/dev/null | grep -q "trustedCertEntry"; then
    echo "   ✅ truststore.p12 verification successful"
else
    echo "   ⚠️  Warning: truststore.p12 verification failed"
fi

echo "🚀 Starting WSO2 API Manager..."

# Start WSO2 APIM with original entrypoint
exec /home/wso2carbon/docker-entrypoint.sh "$@"
