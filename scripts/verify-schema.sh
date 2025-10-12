#!/bin/bash
# =================================================================
# WSO2 IS 7.1.0 Database Schema Verification Script
# =================================================================
# This script verifies that the database schema has all required
# columns for WSO2 IS 7.1.0 to start successfully
# =================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "================================================================"
echo "WSO2 IS 7.1.0 Database Schema Verification"
echo "================================================================"
echo ""

# Configuration
DB_HOST="${DB_HOST:-mysql}"
DB_PORT="${DB_PORT:-3306}"
DB_NAME="${DB_NAME:-WSO2AM_DB}"
DB_USER="${DB_USER:-wso2carbon}"
DB_PASS="${DB_PASS:-wso2carbon}"

# Check if running in Docker context
if docker ps --format '{{.Names}}' | grep -q mysql; then
    echo -e "${GREEN}✓ MySQL container detected${NC}"
    MYSQL_CONTAINER=$(docker ps --format '{{.Names}}' | grep mysql | head -1)
    DOCKER_EXEC="docker exec -i $MYSQL_CONTAINER"
else
    echo -e "${YELLOW}! MySQL container not found, attempting direct connection${NC}"
    DOCKER_EXEC=""
fi

# Function to run SQL queries
run_query() {
    local query="$1"
    if [ -n "$DOCKER_EXEC" ]; then
        echo "$query" | $DOCKER_EXEC mysql -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" 2>/dev/null
    else
        echo "$query" | mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" 2>/dev/null
    fi
}

echo "Checking database connectivity..."
if run_query "SELECT 1;" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Database connection successful${NC}"
else
    echo -e "${RED}✗ Cannot connect to database${NC}"
    echo "  Host: $DB_HOST:$DB_PORT"
    echo "  Database: $DB_NAME"
    echo "  User: $DB_USER"
    exit 1
fi

echo ""
echo "================================================================"
echo "Critical Column Checks (WSO2 IS 7.1.0)"
echo "================================================================"
echo ""

ISSUES_FOUND=0

# Check for AUTHENTICATION_TYPE column
echo -e "${BLUE}Checking IDP_AUTHENTICATOR.AUTHENTICATION_TYPE...${NC}"
result=$(run_query "SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='$DB_NAME' AND TABLE_NAME='IDP_AUTHENTICATOR' AND COLUMN_NAME='AUTHENTICATION_TYPE';")
count=$(echo "$result" | tail -1)

if [ "$count" = "1" ]; then
    echo -e "${GREEN}✓ AUTHENTICATION_TYPE column exists${NC}"
    
    # Get column details
    details=$(run_query "SELECT COLUMN_TYPE, IS_NULLABLE, COLUMN_DEFAULT FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='$DB_NAME' AND TABLE_NAME='IDP_AUTHENTICATOR' AND COLUMN_NAME='AUTHENTICATION_TYPE';" | tail -n +2)
    echo "  Details: $details"
else
    echo -e "${RED}✗ AUTHENTICATION_TYPE column MISSING${NC}"
    ISSUES_FOUND=1
fi

# Check for DEFINED_BY column
echo -e "${BLUE}Checking IDP_AUTHENTICATOR.DEFINED_BY...${NC}"
result=$(run_query "SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='$DB_NAME' AND TABLE_NAME='IDP_AUTHENTICATOR' AND COLUMN_NAME='DEFINED_BY';")
count=$(echo "$result" | tail -1)

if [ "$count" = "1" ]; then
    echo -e "${GREEN}✓ DEFINED_BY column exists${NC}"
else
    echo -e "${RED}✗ DEFINED_BY column MISSING${NC}"
    ISSUES_FOUND=1
fi

# Check for CURSOR_KEY column in API_RESOURCE
echo -e "${BLUE}Checking API_RESOURCE.CURSOR_KEY...${NC}"
result=$(run_query "SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='$DB_NAME' AND TABLE_NAME='API_RESOURCE' AND COLUMN_NAME='CURSOR_KEY';")
count=$(echo "$result" | tail -1)

if [ "$count" = "1" ]; then
    echo -e "${GREEN}✓ CURSOR_KEY column exists${NC}"
else
    echo -e "${RED}✗ CURSOR_KEY column MISSING${NC}"
    ISSUES_FOUND=1
fi

echo ""
echo "================================================================"
echo "Critical Table Checks"
echo "================================================================"
echo ""

# Check for critical tables
critical_tables=(
    "IDP"
    "IDP_GROUP"
    "IDP_AUTHENTICATOR"
    "IDP_AUTHENTICATOR_PROPERTY"
    "API_RESOURCE"
    "API_RESOURCE_SCOPE"
    "IDN_CERT_VALIDATOR"
    "IDN_CONFIG_TYPE"
)

for table in "${critical_tables[@]}"; do
    result=$(run_query "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='$DB_NAME' AND TABLE_NAME='$table';")
    count=$(echo "$result" | tail -1)
    
    if [ "$count" = "1" ]; then
        echo -e "${GREEN}✓${NC} Table $table exists"
    else
        echo -e "${RED}✗${NC} Table $table MISSING"
        ISSUES_FOUND=1
    fi
done

echo ""
echo "================================================================"
echo "Configuration Type Checks"
echo "================================================================"
echo ""

# Check for required configuration types
config_types=(
    "CERTIFICATE_VALIDATOR"
    "API_RESOURCE"
    "REMOTE_LOGGING_CONFIG"
)

for config_type in "${config_types[@]}"; do
    result=$(run_query "SELECT COUNT(*) FROM IDN_CONFIG_TYPE WHERE NAME='$config_type';" 2>/dev/null || echo "0")
    count=$(echo "$result" | tail -1)
    
    if [ "$count" = "1" ]; then
        echo -e "${GREEN}✓${NC} Config type $config_type exists"
    else
        echo -e "${RED}✗${NC} Config type $config_type MISSING"
        ISSUES_FOUND=1
    fi
done

echo ""
echo "================================================================"
echo "IDP_AUTHENTICATOR Table Structure"
echo "================================================================"
echo ""
run_query "DESCRIBE IDP_AUTHENTICATOR;"

echo ""
echo "================================================================"
echo "Data Verification"
echo "================================================================"
echo ""

# Check if there's any data in critical tables
echo "Checking for existing data..."
idp_count=$(run_query "SELECT COUNT(*) FROM IDP;" | tail -1 2>/dev/null || echo "0")
echo "  IDP records: $idp_count"

app_count=$(run_query "SELECT COUNT(*) FROM SP_APP;" | tail -1 2>/dev/null || echo "0")
echo "  SP_APP records: $app_count"

oauth_count=$(run_query "SELECT COUNT(*) FROM IDN_OAUTH_CONSUMER_APPS;" | tail -1 2>/dev/null || echo "0")
echo "  OAuth apps: $oauth_count"

echo ""
echo "================================================================"
echo "Summary"
echo "================================================================"
echo ""

if [ "$ISSUES_FOUND" -eq 0 ]; then
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✓ All checks passed! Database schema is ready for WSO2 IS 7.1.0${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Start WSO2 IS: docker compose up -d is-as-km"
    echo "  2. Monitor logs: docker compose logs -f is-as-km"
    echo "  3. Access admin console: https://localhost:9444/carbon"
    echo ""
    exit 0
else
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}✗ Issues found in database schema${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Required actions:"
    echo "  1. Apply migration: docker exec -i \$(docker ps -qf \"name=mysql\") mysql -uwso2carbon -pwso2carbon WSO2AM_DB < conf/mysql/migrations/fix_idp_authenticator_schema.sql"
    echo "  2. Re-run verification: bash scripts/verify-schema.sh"
    echo "  3. Then start WSO2 IS: docker compose up -d"
    echo ""
    exit 1
fi
