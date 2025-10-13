#!/bin/bash
set -e

echo "🔐 Importing SSL Certificates between WSO2 Services"
echo "==================================================="

# Wait for services to be ready
echo "⏳ Waiting for WSO2 IS and APIM to be running..."
sleep 10

# Export WSO2 IS certificate
echo "📤 Exporting WSO2 IS certificate..."
docker compose exec -T wso2is keytool -export -alias wso2carbon \
    -keystore /home/wso2carbon/wso2is-7.1.0/repository/resources/security/wso2carbon.p12 \
    -storetype PKCS12 \
    -file /tmp/wso2is-cert.crt \
    -storepass wso2carbon \
    2>/dev/null || true

# Copy certificate from IS container
docker compose cp wso2is:/tmp/wso2is-cert.crt /tmp/wso2is-cert.crt

# Import IS certificate into APIM trust store
echo "📥 Importing WSO2 IS certificate into APIM truststore..."
docker compose cp /tmp/wso2is-cert.crt wso2apim:/tmp/wso2is-cert.crt

docker compose exec -T wso2apim keytool -import -alias wso2is \
    -keystore /home/wso2carbon/wso2am-4.5.0/repository/resources/security/client-truststore.p12 \
    -storetype PKCS12 \
    -file /tmp/wso2is-cert.crt \
    -storepass wso2carbon \
    -noprompt \
    2>/dev/null || echo "   ⚠️  Certificate might already exist"

# Cleanup
rm -f /tmp/wso2is-cert.crt

echo "✅ Certificate import complete!"
echo "🔄 Restarting WSO2 APIM to apply changes..."
docker compose restart wso2apim

echo "⏳ Waiting for APIM to restart..."
sleep 30

echo "✅ Done! APIM should now trust WSO2 IS certificates."
