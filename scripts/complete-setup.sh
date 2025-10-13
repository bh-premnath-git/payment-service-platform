#!/bin/bash
set -e

echo "🚀 Complete WSO2 Setup with IDN_CONFIG_RESOURCE Fix"
echo "=================================================="

# 1. Clean slate
echo "🧹 Cleaning previous setup..."
docker compose down -v
sleep 5

# 2. Start PostgreSQL
echo "📦 Starting PostgreSQL..."
docker compose up -d postgres

# Wait for PostgreSQL to be ready
echo "⏳ Waiting for PostgreSQL..."
until docker compose exec -T postgres pg_isready -U postgres > /dev/null 2>&1; do
    echo "   Waiting for PostgreSQL..."
    sleep 2
done
echo "✅ PostgreSQL ready"
sleep 5

# 3. Start WSO2 IS (first boot - creates tables)
echo "🔐 Starting WSO2 Identity Server (initial boot)..."
docker compose up -d wso2is

# 4. Wait for table creation
echo "⏳ Waiting for WSO2 IS to create tables..."
ATTEMPTS=0
MAX_ATTEMPTS=60
until docker compose exec -T postgres psql -U postgres -d wso2is_db -t -c "SELECT 1 FROM information_schema.tables WHERE table_name = 'idn_config_resource';" 2>/dev/null | grep -q 1; do
    ATTEMPTS=$((ATTEMPTS+1))
    if [ $ATTEMPTS -ge $MAX_ATTEMPTS ]; then
        echo "❌ Timeout waiting for tables"
        exit 1
    fi
    echo "   Waiting for table creation... ($ATTEMPTS/$MAX_ATTEMPTS)"
    sleep 3
done

echo "✅ Table idn_config_resource created"
sleep 5

# 5. Apply the fix IMMEDIATELY
echo "🔧 Applying IDN_CONFIG_RESOURCE fix..."
docker compose exec -T postgres psql -U postgres -d wso2is_db << 'EOF'
-- Fix the created_time column
ALTER TABLE public.idn_config_resource 
ALTER COLUMN created_time SET DEFAULT CURRENT_TIMESTAMP;

-- Fix any existing NULL values
UPDATE public.idn_config_resource 
SET created_time = COALESCE(created_time, last_modified, CURRENT_TIMESTAMP)
WHERE created_time IS NULL;

-- Verify the fix
\echo 'Verification:'
SELECT 
    column_name, 
    column_default, 
    is_nullable,
    data_type
FROM information_schema.columns 
WHERE table_name = 'idn_config_resource' 
  AND column_name = 'created_time';

\echo 'Row count:'
SELECT COUNT(*) as total_rows, 
       COUNT(created_time) as non_null_created_time 
FROM idn_config_resource;
EOF

if [ $? -eq 0 ]; then
    echo "✅ Fix applied successfully"
else
    echo "❌ Failed to apply fix"
    exit 1
fi

# 6. Restart WSO2 IS to clear any errors
echo "🔄 Restarting WSO2 IS..."
docker compose restart wso2is

# 7. Wait for WSO2 IS to be fully ready
echo "⏳ Waiting for WSO2 IS to start..."
sleep 60

# 8. Initialize other databases
echo "📊 Initializing WSO2 APIM databases..."
if [ -f "./scripts/init-wso2-databases.sh" ]; then
    ./scripts/init-wso2-databases.sh
else
    echo "⚠️  init-wso2-databases.sh not found, skipping"
fi

# 9. Start remaining services
echo "🚀 Starting WSO2 APIM and other services..."
docker compose up -d

# 10. Final verification
echo ""
echo "🔍 Final Verification..."
echo "========================"

# Check for errors in logs
if docker compose logs wso2is | grep -i "null value in column \"created_time\"" > /dev/null; then
    echo "❌ Still seeing created_time errors!"
    docker compose logs wso2is | grep -A 5 "created_time"
else
    echo "✅ No created_time errors found"
fi

# Check table
docker compose exec -T postgres psql -U postgres -d wso2is_db -c "
SELECT 'Table Status:' as info;
SELECT column_name, column_default, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'idn_config_resource' 
  AND column_name IN ('created_time', 'last_modified');
"

echo ""
echo "✅ Setup Complete!"
echo "=================="
echo ""
echo "🌐 Access URLs:"
echo "   • WSO2 IS Console: https://localhost:9443/console"
echo "   • WSO2 APIM Publisher: https://localhost:9444/publisher"
echo "   • WSO2 APIM DevPortal: https://localhost:9444/devportal"
echo ""
echo "🔐 Default Credentials: admin / admin"
echo ""
echo "📋 Monitor logs:"
echo "   docker compose logs -f wso2is"
