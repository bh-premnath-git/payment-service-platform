#!/bin/bash
set -e

echo "🔧 Quick Fix for Running System"
echo "================================"

# Check if table exists first
echo "🔍 Checking if fix is needed..."
TABLE_EXISTS=$(docker compose exec -T postgres psql -U postgres -d wso2is_db -t -c "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'idn_config_resource');" 2>/dev/null | tr -d ' ')

if [ "$TABLE_EXISTS" != "t" ]; then
    echo "❌ Table idn_config_resource does not exist yet. Run complete-setup.sh first."
    exit 1
fi

# Check if fix is already applied
CURRENT_DEFAULT=$(docker compose exec -T postgres psql -U postgres -d wso2is_db -t -c "SELECT column_default FROM information_schema.columns WHERE table_name = 'idn_config_resource' AND column_name = 'created_time';" 2>/dev/null | tr -d ' ')

if [ "$CURRENT_DEFAULT" = "CURRENT_TIMESTAMP" ]; then
    echo "✅ Fix is already applied. Nothing to do."
    exit 0
fi

# Stop WSO2 IS
echo "⏸️  Stopping WSO2 IS..."
docker compose stop wso2is

# Apply fix
echo "🔧 Applying fix to database..."
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

-- Verify
\echo ''
\echo '✅ Fix applied. Verification:'
\echo '=============================='
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
\echo 'Row count analysis:'
SELECT 
    COUNT(*) as total_rows, 
    COUNT(created_time) as non_null_created_time,
    COUNT(*) - COUNT(created_time) as null_count
FROM idn_config_resource;
EOF

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Fix applied successfully"
else
    echo ""
    echo "❌ Failed to apply fix"
    exit 1
fi

# Restart
echo "▶️  Restarting WSO2 IS..."
docker compose start wso2is

# Wait for health check
echo "⏳ Waiting for WSO2 IS to be healthy..."
sleep 10

# Check if there are still errors
echo ""
echo "🔍 Checking for errors in logs..."
if docker compose logs wso2is --since 2m | grep -i "null value in column \"created_time\"" > /dev/null; then
    echo "⚠️  Warning: Still seeing created_time errors in logs"
else
    echo "✅ No created_time errors detected"
fi

echo ""
echo "✅ Quick fix complete!"
echo ""
echo "📋 Monitor logs with:"
echo "   docker compose logs -f wso2is"
echo ""
echo "🌐 Access WSO2 IS Console:"
echo "   https://localhost:9443/console"
