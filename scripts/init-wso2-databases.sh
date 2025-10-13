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

# Function to check if database has tables
check_tables() {
    local db=$1
    local count=$(docker compose exec -T postgres psql -U postgres -d "$db" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE';" 2>/dev/null | tr -d ' ')
    echo "$count"
}

# Initialize Shared DB (must be done first)
echo "   → Checking Shared DB (wso2shared_db)..."
SHARED_TABLES=$(check_tables "wso2shared_db")
if [ "$SHARED_TABLES" -gt 0 ]; then
    echo "   ⏭️  Shared DB already initialized ($SHARED_TABLES tables exist), skipping..."
else
    echo "   → Initializing Shared DB..."
    docker compose exec -T postgres psql -U wso2user -d wso2shared_db < /tmp/shared-postgres.sql
fi

# Initialize APIM DB
echo "   → Checking APIM DB (wso2am_db)..."
APIM_TABLES=$(check_tables "wso2am_db")
if [ "$APIM_TABLES" -gt 0 ]; then
    echo "   ⏭️  APIM DB already initialized ($APIM_TABLES tables exist), skipping..."
else
    echo "   → Initializing APIM DB..."
    docker compose exec -T postgres psql -U wso2user -d wso2am_db < /tmp/apimgt-postgres.sql
fi

# Initialize IS DB
echo "   → Checking Identity DB (wso2is_db)..."
IS_TABLES=$(check_tables "wso2is_db")
if [ "$IS_TABLES" -gt 0 ]; then
    echo "   ⏭️  Identity DB already initialized ($IS_TABLES tables exist), skipping..."
else
    echo "   → Initializing Identity DB..."
    docker compose exec -T postgres psql -U wso2user -d wso2is_db < /tmp/identity-postgres.sql
fi

echo "✅ Database initialization complete!"
echo ""
echo "📊 Database Summary:"
echo "   - wso2shared_db: User management and registry"
echo "   - wso2am_db: API Manager data"
echo "   - wso2is_db: Identity Server data"
