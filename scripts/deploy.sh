#!/bin/bash
# =================================================================
# Automated WSO2 Platform Deployment Script
# =================================================================
# This script automates the complete deployment process with
# schema verification and health checks
# =================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "================================================================"
echo "WSO2 Payment Service Platform - Automated Deployment"
echo "================================================================"
echo ""

# Step 1: Clean up
echo -e "${BLUE}[1/6] Cleaning up existing containers and volumes...${NC}"
docker compose down -v
echo -e "${GREEN}✓ Cleanup complete${NC}"
echo ""

# Step 2: Build images
echo -e "${BLUE}[2/6] Building Docker images...${NC}"
docker compose build
echo -e "${GREEN}✓ Build complete${NC}"
echo ""

# Step 3: Start MySQL
echo -e "${BLUE}[3/6] Starting MySQL database...${NC}"
docker compose up -d mysql
echo "Waiting for MySQL to be healthy..."

# Wait for MySQL healthcheck
timeout=120
elapsed=0
while [ $elapsed -lt $timeout ]; do
    if docker compose ps mysql | grep -q "healthy"; then
        echo -e "${GREEN}✓ MySQL is healthy${NC}"
        break
    fi
    sleep 5
    elapsed=$((elapsed + 5))
    echo -n "."
done

if [ $elapsed -ge $timeout ]; then
    echo -e "${RED}✗ MySQL failed to become healthy within ${timeout}s${NC}"
    echo "Logs:"
    docker compose logs mysql | tail -50
    exit 1
fi
echo ""

# Step 4: Verify schema
echo -e "${BLUE}[4/6] Verifying database schema...${NC}"
sleep 5  # Give MySQL a moment to settle
if bash scripts/verify-schema.sh; then
    echo -e "${GREEN}✓ Schema verification passed${NC}"
else
    echo -e "${RED}✗ Schema verification failed${NC}"
    echo "Check the output above for details"
    exit 1
fi
echo ""

# Step 5: Start IS-AS-KM
echo -e "${BLUE}[5/6] Starting WSO2 Identity Server (Key Manager)...${NC}"
docker compose up -d is-as-km
echo "Waiting for IS-AS-KM to be healthy (this may take 2-3 minutes)..."

timeout=300
elapsed=0
while [ $elapsed -lt $timeout ]; do
    if docker compose ps is-as-km | grep -q "healthy"; then
        echo -e "${GREEN}✓ IS-AS-KM is healthy${NC}"
        break
    fi
    
    # Check for errors
    if docker compose ps is-as-km | grep -q "unhealthy"; then
        echo -e "${YELLOW}! IS-AS-KM is unhealthy, checking logs...${NC}"
        docker compose logs is-as-km | grep -i "error\|exception" | tail -20
    fi
    
    sleep 10
    elapsed=$((elapsed + 10))
    printf "."
done
echo ""

if [ $elapsed -ge $timeout ]; then
    echo -e "${RED}✗ IS-AS-KM failed to become healthy within ${timeout}s${NC}"
    echo "Recent logs:"
    docker compose logs is-as-km | tail -100
    exit 1
fi
echo ""

# Step 6: Start API Manager
echo -e "${BLUE}[6/6] Starting WSO2 API Manager...${NC}"
docker compose up -d api-manager
echo "Waiting for API Manager to be healthy (this may take 2-3 minutes)..."

timeout=300
elapsed=0
while [ $elapsed -lt $timeout ]; do
    if docker compose ps api-manager | grep -q "healthy"; then
        echo -e "${GREEN}✓ API Manager is healthy${NC}"
        break
    fi
    
    sleep 10
    elapsed=$((elapsed + 10))
    printf "."
done
echo ""

if [ $elapsed -ge $timeout ]; then
    echo -e "${RED}✗ API Manager failed to become healthy within ${timeout}s${NC}"
    echo "Recent logs:"
    docker compose logs api-manager | tail -100
    exit 1
fi

# Final status
echo ""
echo "================================================================"
echo "Deployment Summary"
echo "================================================================"
echo ""
docker compose ps
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ All services are running and healthy!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Access URLs:"
echo "  • IS Admin Console:    https://localhost:9444/carbon"
echo "  • APIM Publisher:      https://localhost:9443/publisher"
echo "  • APIM DevPortal:      https://localhost:9443/devportal"
echo "  • APIM Admin Portal:   https://localhost:9443/admin"
echo ""
echo "Default Credentials:"
echo "  Username: admin"
echo "  Password: admin"
echo ""
echo "Useful Commands:"
echo "  • View all logs:       docker compose logs -f"
echo "  • View IS logs:        docker compose logs -f is-as-km"
echo "  • View APIM logs:      docker compose logs -f api-manager"
echo "  • Stop all services:   docker compose down"
echo "  • Restart a service:   docker compose restart [service-name]"
echo ""
