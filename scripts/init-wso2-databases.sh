#!/bin/bash
set -e

echo "🔧 Extracting WSO2 database scripts from Docker images..."

# Extract APIM database scripts from the container
echo "📦 Extracting APIM scripts..."
docker compose exec -T wso2apim cat /home/wso2carbon/wso2am-4.5.0/dbscripts/apimgt/postgresql.sql > /tmp/apimgt-postgres.sql
docker compose exec -T wso2apim cat /home/wso2carbon/wso2am-4.5.0/dbscripts/postgresql.sql > /tmp/shared-postgres.sql

# Extract IS database scripts from the container
echo "📦 Extracting IS scripts..."
docker compose exec -T wso2is cat /home/wso2carbon/wso2is-7.1.0/dbscripts/identity/postgresql.sql > /tmp/identity-postgres.sql

echo "🗄️  Initializing databases..."

# Initialize Shared DB (must be done first)
echo "   → Initializing Shared DB (wso2shared_db)..."
docker compose exec -T postgres psql -U wso2user -d wso2shared_db < /tmp/shared-postgres.sql

# Initialize APIM DB
echo "   → Initializing APIM DB (wso2am_db)..."
docker compose exec -T postgres psql -U wso2user -d wso2am_db < /tmp/apimgt-postgres.sql

# Initialize IS DB
echo "   → Initializing Identity DB (wso2is_db)..."
docker compose exec -T postgres psql -U wso2user -d wso2is_db < /tmp/identity-postgres.sql

echo "✅ Database initialization complete!"
echo ""
echo "📊 Database Summary:"
echo "   - wso2shared_db: User management and registry"
echo "   - wso2am_db: API Manager data"
echo "   - wso2is_db: Identity Server data"
