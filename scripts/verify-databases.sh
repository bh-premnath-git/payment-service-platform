#!/bin/bash
# Script to verify WSO2 database initialization

echo "🔍 Verifying WSO2 Database Setup..."
echo ""

# Check if containers are running
echo "📦 Checking container status..."
if ! docker compose ps | grep -q "wso2apim.*Up"; then
    echo "❌ WSO2 APIM container is not running!"
    exit 1
fi

if ! docker compose ps | grep -q "wso2is.*Up"; then
    echo "❌ WSO2 IS container is not running!"
    exit 1
fi

if ! docker compose ps | grep -q "postgres.*Up"; then
    echo "❌ PostgreSQL container is not running!"
    exit 1
fi

echo "✅ All containers are running"
echo ""

# Verify database connections
echo "🔌 Testing database connections..."

# Check wso2shared_db
echo -n "   → wso2shared_db: "
if docker compose exec -T postgres psql -U wso2user -d wso2shared_db -c "SELECT 1;" > /dev/null 2>&1; then
    echo "✅ Connected"
else
    echo "❌ Connection failed"
fi

# Check wso2am_db
echo -n "   → wso2am_db: "
if docker compose exec -T postgres psql -U wso2user -d wso2am_db -c "SELECT 1;" > /dev/null 2>&1; then
    echo "✅ Connected"
else
    echo "❌ Connection failed"
fi

# Check wso2is_db
echo -n "   → wso2is_db: "
if docker compose exec -T postgres psql -U wso2user -d wso2is_db -c "SELECT 1;" > /dev/null 2>&1; then
    echo "✅ Connected"
else
    echo "❌ Connection failed"
fi

echo ""

# Check if tables exist
echo "📊 Checking database tables..."

# Check Shared DB tables
SHARED_TABLES=$(docker compose exec -T postgres psql -U wso2user -d wso2shared_db -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE';" 2>/dev/null | tr -d ' ')
echo "   → wso2shared_db: $SHARED_TABLES tables"

# Check APIM DB tables
APIM_TABLES=$(docker compose exec -T postgres psql -U wso2user -d wso2am_db -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE';" 2>/dev/null | tr -d ' ')
echo "   → wso2am_db: $APIM_TABLES tables"

# Check IS DB tables
IS_TABLES=$(docker compose exec -T postgres psql -U wso2user -d wso2is_db -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE';" 2>/dev/null | tr -d ' ')
echo "   → wso2is_db: $IS_TABLES tables"

echo ""

# Determine initialization status
if [ "$SHARED_TABLES" -gt 0 ] && [ "$APIM_TABLES" -gt 0 ] && [ "$IS_TABLES" -gt 0 ]; then
    echo "✅ All databases are initialized!"
    echo ""
    echo "🎯 You can now access:"
    echo "   • APIM Publisher: https://localhost:9444/publisher"
    echo "   • APIM DevPortal: https://localhost:9444/devportal"
    echo "   • IS Console: https://localhost:9443/console"
    echo "   • Credentials: admin / admin"
else
    echo "⚠️  Databases are NOT initialized or incomplete!"
    echo ""
    echo "📝 Run the initialization script:"
    echo "   ./scripts/init-wso2-databases.sh"
fi

echo ""
