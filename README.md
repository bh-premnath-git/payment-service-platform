# WSO2 API Manager with Identity Server as Key Manager and Analytics Support

## Prerequisites

 * Install [Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git), [Docker](https://www.docker.com/get-docker) and [Docker Compose](https://docs.docker.com/compose/install/#install-compose)
   in order to run the steps provided in following Quick start guide. <br><br>
 * In order to use Docker images with WSO2 updates, you need an active WSO2 subscription.
   If you don't have a valid WSO2 Subscription, you need to build Docker images by source. Build Docker images using Docker resources available in [here](../../dockerfiles/) and replace the `docker.wso2.com/` prefix from the `image` name in the `docker-compose.yml`. <br><br>
* If you are trying this out on Apple Silicon (with M1), build images that supports arm64 architecture according to the instructions in [README](../../dockerfiles/ubuntu/apim/README.md). <br><br>

## Quick Start Guide

1. Login to WSO2's Private Docker Registry via Docker client. When prompted, enter the username and password of your WSO2 Subscription.

   ```
   docker login docker.wso2.com
   ```

2. Clone WSO2 API Management Docker and Docker Compose resource Git repository.

   ```
   git clone https://github.com/wso2/docker-apim
   ```
   
   > If you are to try out an already released zip of this repo, please ignore this 2nd step. 

3. Switch to `docker-compose/apim-is-as-km-with-analytics` folder.

   ```
   cd docker-apim/docker-compose/apim-is-as-km-with-analytics
   ```
   > If you intend to try out an already released zip of this repository, extract the zip file and directly browse to
   `docker-apim-<released-version-here>/docker-compose/apim-is-as-km-with-analytics` folder. 
     
   > If you intend to try out an already released tag, after executing 2nd step, checkout the relevant tag, 
    i.e. for example: `git checkout tags/v4.6.0.1`, switch to `docker-compose/apim-is-as-km-with-analytics` folder and continue with below steps.

4. [Optional] Replace the existing IS extensions with the latest.

   For this, refer to steps `3`, `4` and `5` of the [Configure WSO2 IS section](https://apim.docs.wso2.com/en/latest/administer/key-managers/configure-wso2is-connector/#step-1-configure-wso2-is).
   
   You may replace the JARs in `docker-compose/apim-is-as-km-with-analytics/dockerfiles/is-as-km/dropins` as defined in step 4.
   
   You may replace the web app in `docker-compose/apim-is-as-km-with-analytics/dockerfiles/is-as-km/webapps` as defined in step 5.

5. WSO2 no longer provides an on-premise Analytics solution. In order to connect WSO2 API Manager to [Choreo Analytics](https://analytics.choreo.dev/), obtain an `on-prem-key` by following the steps in the [documentation](https://apim.docs.wso2.com/en/4.6.0/observe/api-manager-analytics/configure-analytics/register-for-analytics/).

6. Update the analytics configurations in [deployment.toml](./conf/apim/repository/conf/deployment.toml) with the `on-prem key` obtained.

    ```toml
    [apim.analytics]
    enable = true
    config_endpoint = "https://analytics-event-auth.choreo.dev/auth/v1"
    auth_token = "on-prem-key"
    ```

7. Execute following Docker Compose command to start the deployment.

   ```
   docker-compose up --build
   ```

8. Access the WSO2 API Manager web UIs using the below URLs via a web browser.

   ```
   https://localhost:9443/publisher
   https://localhost:9443/devportal
   https://localhost:9443/admin
   https://localhost:9443/carbon
   ```
   Login to the web UIs using following credentials.
   
   * Username: admin <br>
   * Password: admin

   Please note that API Gateway will be available on following ports.
   ```
   https://localhost:8243
   https://localhost:8280
   ```

9. To see analytics data, log in to [Choreo Analytics](https://analytics.choreo.dev/).

Note: In order to support the renewed wso2carbon certificate in API Manager, we are mounting wso2carbon and client-truststore keystores with the renewed certificate in the Identity Server.
WSO2 API Manager with Identity Server as Key Manager
🏗️ Architecture Overview
┌─────────────────────────────────────────────────────────────────┐
│                         Docker Network                           │
├─────────────────┬───────────────────┬────────────────────────────┤
│   MySQL 8.0.36  │  WSO2 IS-AS-KM    │  WSO2 API Manager 4.6.0   │
│   Port: 3306    │  Port: 9444       │  Ports: 9443, 8280, 8243  │
│                 │  (Key Manager)    │  (API Gateway)             │
│   Databases:    │  Version: 6.1.0.0 │                            │
│   - WSO2AM_DB   │                   │                            │
│   - WSO2AM_     │  ┌──────────────┐ │  ┌──────────────────────┐ │
│     SHARED_DB   │  │ OAuth/Token  │ │  │ API Gateway          │ │
│                 │  │ Management   │◄┼──┤ Developer Portal     │ │
│                 │  │              │ │  │ Publisher Portal     │ │
│                 │  └──────────────┘ │  │ Admin Portal         │ │
│                 │                   │  └──────────────────────┘ │
└─────────────────┴───────────────────┴────────────────────────────┘
📋 Components
1. WSO2 API Manager (APIM) 4.6.0.0

Role: API Gateway, Publisher, Developer Portal, Admin Portal
Key Features:

API lifecycle management
API analytics integration (Choreo)
Rate limiting & throttling
OAuth2 token validation (delegates to IS)


Exposed Ports:

9443: HTTPS management console
8280: HTTP API traffic
8243: HTTPS API traffic



2. WSO2 Identity Server (IS) 6.1.0.0 - As Key Manager

Role: OAuth2 Authorization Server, Key Manager
Key Responsibilities:

OAuth2 token issuance/revocation
Client credentials management
User authentication
Token introspection


Exposed Port: 9444 (HTTPS)
Extensions:

Custom JARs in dockerfiles/is-as-km/dropins/
Custom webapps in dockerfiles/is-as-km/webapps/



3. MySQL 8.0.36

Databases:

WSO2AM_DB: API Manager data (APIs, subscriptions, applications)
WSO2AM_SHARED_DB: Shared registry/user management


Configuration: SSL disabled for development

🔧 Configuration Details
Volume Mounts
yamlis-as-km:
  volumes:
    - ./conf/is-as-km:/home/wso2carbon/wso2-config-volume

api-manager:
  volumes:
    - ./conf/apim:/home/wso2carbon/wso2-config-volume
Mounted Files:

deployment.toml: Primary configuration
identity.xml.j2: Identity provider templates
Keystores: wso2carbon.jks, client-truststore.jks

Database Configuration
Both APIM and IS-AS-KM connect to MySQL:
toml[database.shared_db]
type = "mysql"
url = "jdbc:mysql://mysql:3306/WSO2AM_SHARED_DB?autoReconnect=true&allowPublicKeyRetrieval=true&useSSL=false"
username = "wso2carbon"
password = "wso2carbon"
driver = "com.mysql.cj.jdbc.Driver"
Keystore Configuration
API Manager (conf/apim/repository/conf/deployment.toml):
toml[keystore.tls]
file_name = "wso2carbon.jks"
type = "JKS"
password = "wso2carbon"
alias = "wso2carbon"
key_password = "wso2carbon"
Identity Server (conf/is-as-km/repository/conf/deployment.toml):
toml[keystore]
userstore_password_encryption = "InternalKeyStore"

[truststore]
file_name = "client-truststore.jks"
password = "wso2carbon"
type = "JKS"
🚨 ERROR: Invalid Keystore Format
Problem Analysis
After downgrading WSO2 IS, you're encountering:
ERROR - An error occurred while loading the internal keystore
Caused by: java.io.IOException: Invalid keystore format
Root Causes:

Keystore Format Mismatch:

Newer Java versions (11+) default to PKCS12 format
WSO2 IS 6.1.0 expects JKS format
Downgrade may have left PKCS12 keystores


Empty Configuration Values:

   NumberFormatException: For input string: ""

Missing tenant context rewrite configuration
Empty port/timeout values after downgrade


Certificate Incompatibility:

Keystores created with different certificate authorities
Mismatched keystore passwords/aliases



🔍 Diagnostic Steps
1. Identify Keystore Format
bash# Check current keystore format
docker exec is-as-km-1 keytool -list -v \
  -keystore /home/wso2carbon/wso2is-km/repository/resources/security/wso2carbon.jks \
  -storepass wso2carbon | head -20

# Look for:
# - "Keystore type: JKS" (correct)
# - "Keystore type: PKCS12" (needs conversion)
2. Verify Java Version
bashdocker exec is-as-km-1 java -version

# WSO2 IS 6.1.0 requires Java 11
# Check for JDK version mismatch
3. Check Configuration Files
bash# Find empty configuration values
docker exec is-as-km-1 grep -r "=" \
  /home/wso2carbon/wso2is-km/repository/conf/ | grep '=""'
✅ Resolution Methods
Method 1: Regenerate Keystores (Recommended for Dev)
bash# 1. Stop containers
docker compose down

# 2. Backup existing keystores
mkdir -p ./keystore-backup
docker run --rm -v $(pwd)/conf/is-as-km:/source -v $(pwd)/keystore-backup:/backup \
  alpine sh -c "cp -r /source/repository/resources/security/* /backup/ 2>/dev/null || true"

# 3. Remove old keystores from host (they'll be regenerated)
rm -rf ./conf/is-as-km/repository/resources/security/*.jks

# 4. Rebuild and start (WSO2 generates default keystores)
docker compose up --build -d

# 5. Wait for startup
docker compose logs -f is-as-km | grep -i "Mgt Console URL"
Trade-offs:

✅ Clean slate, guaranteed compatibility
✅ Simplest solution
❌ Loses existing certificates (acceptable for dev)
❌ Need to reconfigure encrypted passwords

Method 2: Convert PKCS12 to JKS
bash# 1. Enter container
docker exec -it is-as-km-1 bash

# 2. Navigate to security directory
cd /home/wso2carbon/wso2is-km/repository/resources/security

# 3. Backup
cp wso2carbon.jks wso2carbon.jks.backup

# 4. Convert PKCS12 → JKS
keytool -importkeystore \
  -srckeystore wso2carbon.jks \
  -destkeystore wso2carbon_jks.jks \
  -srcstoretype PKCS12 \
  -deststoretype JKS \
  -srcstorepass wso2carbon \
  -deststorepass wso2carbon

# 5. Replace
mv wso2carbon_jks.jks wso2carbon.jks

# 6. Fix permissions
chown wso2carbon:wso2 wso2carbon.jks
chmod 644 wso2carbon.jks

# 7. Exit and restart
exit
docker compose restart is-as-km
Method 3: Fix Configuration Issues
Add missing tenant context configuration to conf/is-as-km/repository/conf/deployment.toml:
toml# Add this section if missing
[tenant_context.rewrite]
custom_webapps = ["/keymanager-operations/"]
webapps = []

# Ensure entitlement thrift port is set
[entitlement.thrift]
enable = true
receiver_port = 10500
client_timeout = 10000

[entitlement.thrift.key_store]
id = "wso2carbon.jks"
password = "wso2carbon"
Method 4: Use Pre-Existing Compatible Keystores
If you have known-good keystores:
bash# 1. Stop containers
docker compose down

# 2. Copy known-good keystores
cp /path/to/working/wso2carbon.jks ./conf/is-as-km/repository/resources/security/
cp /path/to/working/client-truststore.jks ./conf/is-as-km/repository/resources/security/

# 3. Ensure proper permissions
chmod 644 ./conf/is-as-km/repository/resources/security/*.jks

# 4. Restart
docker compose up -d
🔄 Complete Recovery Procedure
Step-by-Step Clean Deployment
bash# 1. Complete teardown
docker compose down -v
docker system prune -f

# 2. Clear any mounted volumes
rm -rf ./conf/is-as-km/repository/resources/security/*.jks 2>/dev/null || true

# 3. Verify MySQL scripts are ready
ls -la conf/mysql/scripts/

# 4. Build fresh images
docker compose build --no-cache

# 5. Start MySQL first
docker compose up -d mysql

# 6. Wait for MySQL init (check for initialization flag)
docker compose logs mysql | grep "initialization-complete"

# 7. Start IS-AS-KM
docker compose up -d is-as-km

# 8. Monitor IS startup
docker compose logs -f is-as-km

# Watch for:
# ✅ "Mgt Console URL : https://localhost:9444/carbon"
# ❌ Any "Invalid keystore format" errors

# 9. Once IS is healthy, start APIM
docker compose up -d api-manager

# 10. Verify all services
docker compose ps
docker compose logs api-manager | grep "Mgt Console URL"
Verification Checklist
bash# 1. Check health endpoints
curl -k https://localhost:9444/api/health-check/v1.0/health
curl http://localhost:9763/services/Version

# 2. Verify keystores inside container
docker exec is-as-km-1 keytool -list \
  -keystore /home/wso2carbon/wso2is-km/repository/resources/security/wso2carbon.jks \
  -storepass wso2carbon | grep "Keystore type"

# Should show: Keystore type: JKS

# 3. Test APIM portals
# Open browser:
# - https://localhost:9443/carbon (APIM Admin)
# - https://localhost:9444/carbon (IS Admin)
# Login: admin/admin

# 4. Verify database connectivity
docker exec mysql mysql -uroot -proot -e "SHOW DATABASES;"
# Should list: WSO2AM_DB, WSO2AM_SHARED_DB
🛠️ Troubleshooting Guide
Issue: "Unable to decrypt encrypted field: password"
Cause: Keystore changed, encrypted passwords invalid
Fix:
toml# In deployment.toml, temporarily use plaintext
[database.shared_db]
password = "wso2carbon"  # Instead of encrypted

# Re-encrypt after keystore is stable:
# ./wso2server.sh -Dconfigure
Issue: Container keeps restarting
bash# 1. Check actual error
docker compose logs is-as-km --tail 50

# 2. Disable healthcheck temporarily
# In docker-compose.yml:
# healthcheck:
#   disable: true

# 3. Investigate startup
docker compose up is-as-km  # No -d flag, see output
Issue: Port conflicts
bash# Check what's using ports
sudo netstat -tulpn | grep -E "9443|9444|8280|8243"

# Change ports in docker-compose.yml
ports:
  - "19443:9443"  # Prefix with 1
Issue: MySQL connection refused
bash# 1. Verify MySQL is healthy
docker compose exec mysql mysqladmin ping -uroot -proot

# 2. Check init scripts ran
docker compose exec mysql ls -la /var/lib/mysql/initialization-complete.flag

# 3. Manually verify databases
docker compose exec mysql mysql -uroot -proot \
  -e "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME LIKE 'WSO2%';"
📊 Monitoring & Logs
Real-time Log Monitoring
bash# All services
docker compose logs -f

# Specific service
docker compose logs -f is-as-km

# Filter errors only
docker compose logs is-as-km 2>&1 | grep -i -E "error|exception|fatal"

# Last 100 lines
docker compose logs --tail 100 is-as-km
Performance Metrics
bash# Container resource usage
docker stats

# Check if container is CPU/memory bound
docker inspect is-as-km-1 --format='{{.State.Health.Status}}'
🎯 Best Practices
1. Version Pinning
dockerfile# Always pin exact versions
FROM wso2/wso2is:6.1.0.0  # ✅ Specific
FROM wso2/wso2is:latest   # ❌ Unpredictable
2. Keystore Management

Keep keystores in version control for dev environments
Use secrets management for production (Docker Swarm secrets, Kubernetes secrets)
Document keystore passwords securely (e.g., AWS Secrets Manager)

3. Database Initialization
bash# Ensure idempotent SQL scripts
CREATE TABLE IF NOT EXISTS ...  # ✅
CREATE TABLE ...                # ❌ Fails on restart
4. Health Checks
yamlhealthcheck:
  test: ["CMD", "curl", "--fail", "https://localhost:9444/api/health-check/v1.0/health"]
  interval: 10s
  start_period: 180s  # IS needs time to initialize
  retries: 20
5. Dependency Management
yamldepends_on:
  mysql:
    condition: service_healthy  # ✅ Wait for MySQL
  mysql: []                     # ❌ Starts in parallel
🔐 Security Considerations
Development vs Production
Development (current setup):
tomlhostname = "localhost"
[database.shared_db]
url = "...useSSL=false"  # OK for dev
Production (recommended):
tomlhostname = "api.yourcompany.com"

[database.shared_db]
url = "...useSSL=true&requireSSL=true"

[keystore.tls]
file_name = "production.jks"  # Real CA-signed cert
Keystore Password Rotation
bash# 1. Change keystore password
keytool -storepasswd \
  -keystore wso2carbon.jks \
  -storepass wso2carbon \
  -new newpassword123

# 2. Update deployment.toml
[keystore.tls]
password = "newpassword123"

# 3. Rebuild containers
docker compose up -d --build
📚 Additional Resources

WSO2 IS Documentation: https://is.docs.wso2.com/en/6.1.0/
WSO2 APIM Documentation: https://apim.docs.wso2.com/en/4.6.0/
Key Manager Configuration: https://apim.docs.wso2.com/en/latest/administer/key-managers/configure-wso2is-connector/
Choreo Analytics: https://analytics.choreo.dev/

🤝 Support
Quick Diagnostics
bash# Generate diagnostic report
cat > diagnose.sh << 'EOF'
#!/bin/bash
echo "=== Docker Compose Status ==="
docker compose ps

echo -e "\n=== IS Keystore Type ==="
docker exec is-as-km-1 keytool -list -v \
  -keystore /home/wso2carbon/wso2is-km/repository/resources/security/wso2carbon.jks \
  -storepass wso2carbon 2>&1 | grep -E "Keystore type|Alias name"

echo -e "\n=== Recent Errors ==="
docker compose logs is-as-km 2>&1 | grep -i error | tail -10

echo -e "\n=== Java Version ==="
docker exec is-as-km-1 java -version 2>&1

echo -e "\n=== MySQL Status ==="
docker compose exec mysql mysqladmin ping -uroot -proot 2>&1
EOF

chmod +x diagnose.sh
./diagnose.sh

🎬 Quick Start Commands
bash# Fresh deployment
docker compose down -v && docker compose up --build -d

# Restart single service
docker compose restart is-as-km

# Reset everything (nuclear option)
docker compose down -v
docker system prune -af --volumes
rm -rf conf/is-as-km/repository/resources/security/*.jks
docker compose up --build

Last Updated: October 2025
Tested With: Docker 24+, Docker Compose 2.20+, WSO2 IS 6.1.0.0, WSO2 APIM 4.6.0.0