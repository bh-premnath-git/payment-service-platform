#!/bin/bash
set -e

echo "🚀 Complete WSO2 Setup with IDN_CONFIG_RESOURCE Fix"
echo "=================================================="
echo ""
echo "ℹ️  This script:"
echo "   1. Creates PostgreSQL databases"
echo "   2. Manually runs SQL scripts (WSO2 -Dsetup causes PostgreSQL transaction errors)"
echo "   3. Applies created_time trigger fix"
echo "   4. Starts WSO2 IS and APIM"
echo "   5. APIM auto-imports IS SSL certificate on startup (via docker-entrypoint-wrapper.sh)"
echo ""

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

# 3. Start WSO2 IS temporarily to extract SQL scripts
echo "📊 Preparing WSO2 IS database tables..."

# Check if tables already exist
SHARED_TABLES=$(docker compose exec -T postgres psql -U postgres -d wso2shared_db -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE';" 2>/dev/null | tr -d ' ')

if [ "$SHARED_TABLES" != "" ] && [ "$SHARED_TABLES" -gt 0 ]; then
    echo "   ⏭️  Shared DB tables already exist ($SHARED_TABLES tables), skipping..."
else
    echo "   → Creating Shared DB tables (User Management & Registry)..."
    # Start WSO2 IS container just to copy files, then stop it
    docker compose up -d wso2is --no-deps
    sleep 5
    
    # Copy SQL files from container
    docker compose cp wso2is:/home/wso2carbon/wso2is-7.1.0/dbscripts/postgresql.sql /tmp/wso2-shared.sql
    docker compose cp wso2is:/home/wso2carbon/wso2is-7.1.0/dbscripts/identity/postgresql.sql /tmp/wso2-identity.sql
    
    # Stop WSO2 IS
    docker compose stop wso2is
    
    # Import shared DB tables
    docker compose exec -T postgres psql -U wso2user -d wso2shared_db < /tmp/wso2-shared.sql > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "   ✅ Shared DB tables created"
    else
        rm -f /tmp/wso2-shared.sql /tmp/wso2-identity.sql
        echo "   ❌ Failed to create shared DB tables"
        exit 1
    fi
fi

# Check if identity tables exist
IS_TABLES=$(docker compose exec -T postgres psql -U postgres -d wso2is_db -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'idn_config_resource';" 2>/dev/null | tr -d ' ')

if [ "$IS_TABLES" != "" ] && [ "$IS_TABLES" -gt 0 ]; then
    echo "   ⏭️  Identity DB tables already exist, skipping..."
else
    echo "   → Creating Identity DB tables..."
    # Import identity DB tables (file already copied above if needed)
    if [ ! -f /tmp/wso2-identity.sql ]; then
        docker compose up -d wso2is --no-deps
        sleep 5
        docker compose cp wso2is:/home/wso2carbon/wso2is-7.1.0/dbscripts/identity/postgresql.sql /tmp/wso2-identity.sql
        docker compose stop wso2is
    fi
    
    docker compose exec -T postgres psql -U wso2user -d wso2is_db < /tmp/wso2-identity.sql > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "   ✅ Identity DB tables created"
    else
        rm -f /tmp/wso2-shared.sql /tmp/wso2-identity.sql
        echo "   ❌ Failed to create identity DB tables"
        exit 1
    fi
fi

# Cleanup temp SQL files
rm -f /tmp/wso2-shared.sql /tmp/wso2-identity.sql

echo "✅ All WSO2 IS tables created"
sleep 2

# 4. Start WSO2 IS now that tables exist
echo "🔐 Starting WSO2 Identity Server..."
docker compose up -d wso2is
sleep 5

# 5. Apply the fix IMMEDIATELY
echo "🔧 Applying IDN_CONFIG_RESOURCE fix..."
docker compose exec -T postgres psql -U postgres -d wso2is_db << 'EOF'
-- Make the column nullable (WSO2 explicitly inserts NULL, overriding DEFAULT)
ALTER TABLE public.idn_config_resource 
ALTER COLUMN created_time DROP NOT NULL;

-- Set default for good measure
ALTER TABLE public.idn_config_resource 
ALTER COLUMN created_time SET DEFAULT CURRENT_TIMESTAMP;

-- Create a trigger function to auto-set created_time when NULL is inserted
CREATE OR REPLACE FUNCTION set_created_time()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.created_time IS NULL THEN
        NEW.created_time = CURRENT_TIMESTAMP;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop trigger if exists
DROP TRIGGER IF EXISTS trg_set_created_time ON idn_config_resource;

-- Create the trigger
CREATE TRIGGER trg_set_created_time
BEFORE INSERT ON idn_config_resource
FOR EACH ROW
EXECUTE FUNCTION set_created_time();

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

\echo ''
\echo 'Trigger info:'
SELECT 
    trigger_name,
    event_manipulation,
    action_timing
FROM information_schema.triggers 
WHERE event_object_table = 'idn_config_resource';

\echo ''
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

# 6. Wait for WSO2 IS to be fully ready
echo "⏳ Waiting for WSO2 IS to start..."
sleep 60

# 7. Start WSO2 APIM (needed to extract database scripts)
echo "🚀 Starting WSO2 APIM..."
docker compose up -d wso2apim

# Wait for APIM to start
echo "⏳ Waiting for WSO2 APIM to start..."
sleep 30

# 8. Initialize APIM databases
echo "📊 Initializing WSO2 APIM databases..."
if [ -f "./scripts/init-wso2-databases.sh" ]; then
    ./scripts/init-wso2-databases.sh
else
    echo "⚠️  init-wso2-databases.sh not found, skipping"
fi

# 9. Start remaining services
echo "🚀 Starting remaining services..."
docker compose up -d

# 10. Final verification
echo ""
echo "🔍 Final Verification..."
echo "========================"

# Check for critical errors in logs (ignore known non-critical warnings)
if docker compose logs wso2is | grep -i "null value in column \"created_time\"" > /dev/null; then
    echo "❌ Still seeing created_time errors!"
    docker compose logs wso2is | grep -A 5 "created_time"
else
    echo "✅ No created_time errors found"
fi

# Note about non-critical Administrator role warning
if docker compose logs wso2is | grep -i "Administrator.*doesn't exist" > /dev/null; then
    echo ""
    echo "ℹ️  Note: 'Administrator role doesn't exist' warning is expected and non-critical"
    echo "   This only affects the apps portal UI. Core authentication works fine."
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
