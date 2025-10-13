#!/bin/bash
set -e

echo "🔐 APIM Startup: Configuring SSL certificates..."

TRUSTSTORE="/home/wso2carbon/wso2am-4.5.0/repository/resources/security/client-truststore.p12"

# Wait for WSO2 IS to be available and get certificate
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

# Check if certificate already exists
if keytool -list -keystore "$TRUSTSTORE" -storepass wso2carbon -storetype PKCS12 -alias wso2is 2>/dev/null | grep -q "wso2is"; then
    echo "✅ WSO2 IS certificate already exists in truststore"
else
    # Export certificate from WSO2 IS
    echo "📤 Fetching WSO2 IS certificate..."
    echo | openssl s_client -connect wso2is:9443 -servername wso2is 2>/dev/null | \
        openssl x509 -outform PEM > /tmp/wso2is.crt
    
    if [ -s /tmp/wso2is.crt ]; then
        # Import into APIM truststore
        echo "📥 Importing certificate into APIM truststore..."
        keytool -import -noprompt -alias wso2is \
            -keystore "$TRUSTSTORE" \
            -storetype PKCS12 \
            -storepass wso2carbon \
            -file /tmp/wso2is.crt
        
        echo "✅ Certificate imported successfully"
        rm -f /tmp/wso2is.crt
    else
        echo "❌ Failed to fetch certificate from WSO2 IS"
        exit 1
    fi
fi

# Verify certificate is present
if keytool -list -keystore "$TRUSTSTORE" -storepass wso2carbon -storetype PKCS12 -alias wso2is 2>/dev/null | grep -q "trustedCertEntry"; then
    echo "✅ Certificate verification successful"
else
    echo "⚠️  Warning: Certificate verification failed, but continuing..."
fi

echo "🚀 Starting WSO2 API Manager..."

# Start WSO2 APIM with original entrypoint
exec /home/wso2carbon/docker-entrypoint.sh "$@"
