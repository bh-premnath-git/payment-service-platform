#!/bin/bash
set -e

echo "🔧 Quick Fix for Running System"
echo "================================"

# Stop WSO2 IS
echo "⏸️  Stopping WSO2 IS..."
docker compose stop wso2is

# Apply fix
echo "🔧 Applying fix to database..."
docker compose exec -T postgres psql -U postgres -d wso2is_db << 'EOF'
-- Fix the created_time column
ALTER TABLE public.idn_config_resource 
ALTER COLUMN created_time SET DEFAULT CURRENT_TIMESTAMP;

-- Fix any existing NULL values
UPDATE public.idn_config_resource 
SET created_time = COALESCE(created_time, last_modified, CURRENT_TIMESTAMP)
WHERE created_time IS NULL;

-- Verify
\echo '✅ Fix applied. Verification:'
SELECT 
    column_name, 
    column_default, 
    is_nullable,
    data_type
FROM information_schema.columns 
WHERE table_name = 'idn_config_resource' 
  AND column_name = 'created_time';
EOF

if [ $? -eq 0 ]; then
    echo "✅ Fix applied successfully"
else
    echo "❌ Failed to apply fix"
    exit 1
fi

# Restart
echo "▶️  Restarting WSO2 IS..."
docker compose start wso2is

echo ""
echo "✅ Quick fix complete!"
echo ""
echo "📋 Monitor logs:"
echo "   docker compose logs -f wso2is"
