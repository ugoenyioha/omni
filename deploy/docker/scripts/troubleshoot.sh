#!/bin/bash
# Troubleshooting script for omni-docker deployment

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Omni-Docker Troubleshooting Script${NC}"
echo "====================================="

# Function to check service status
check_service() {
    local service=$1
    echo -e "\n${YELLOW}Checking $service...${NC}"
    
    if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "^$service.*Up"; then
        echo -e "${GREEN}✓ $service is running${NC}"
        return 0
    else
        echo -e "${RED}✗ $service is not running${NC}"
        echo "Recent logs:"
        docker logs "$service" --tail 20 2>&1 | sed 's/^/  /'
        return 1
    fi
}

# Function to check network connectivity
check_network() {
    echo -e "\n${YELLOW}Checking network configuration...${NC}"
    
    # Check if macvlan network exists
    if docker network ls | grep -q "omni-macvlan"; then
        echo -e "${GREEN}✓ omni-macvlan network exists${NC}"
        docker network inspect omni-macvlan | jq -r '.[0].IPAM.Config[0] | "  Subnet: \(.Subnet)\n  Gateway: \(.Gateway)"'
    else
        echo -e "${RED}✗ omni-macvlan network not found${NC}"
        echo "  Run create-arch-network.sh or create-qnap-network.sh to create it"
    fi
}

# Function to check certificates
check_certificates() {
    echo -e "\n${YELLOW}Checking certificates...${NC}"
    
    # Check Vault certificates
    if docker exec vault-cert-manager test -f /etc/nginx/ssl/server.crt 2>/dev/null; then
        echo -e "${GREEN}✓ Nginx SSL certificate exists${NC}"
        
        # Check certificate expiry
        expiry=$(docker exec vault-cert-manager openssl x509 -enddate -noout -in /etc/nginx/ssl/server.crt 2>/dev/null | cut -d= -f2)
        echo "  Expires: $expiry"
    else
        echo -e "${RED}✗ Nginx SSL certificate not found${NC}"
        echo "  Check vault-cert-manager logs"
    fi
    
    # Check Matchbox certificates
    if [ -f "matchbox/etc/server.crt" ]; then
        echo -e "${GREEN}✓ Matchbox gRPC certificates exist${NC}"
    else
        echo -e "${RED}✗ Matchbox gRPC certificates not found${NC}"
        echo "  Run generate-matchbox-certs.sh to create them"
    fi
}

# Function to check Vault connectivity
check_vault() {
    echo -e "\n${YELLOW}Checking Vault connectivity...${NC}"
    
    if docker exec vault-cert-manager vault status >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Vault is reachable${NC}"
    else
        echo -e "${RED}✗ Cannot connect to Vault${NC}"
        echo "  Check VAULT_ADDR and network connectivity"
    fi
}

# Function to check endpoints
check_endpoints() {
    echo -e "\n${YELLOW}Checking service endpoints...${NC}"
    
    # Check Omni
    if curl -k -s -o /dev/null -w "%{http_code}" https://localhost/ | grep -q "200\|302"; then
        echo -e "${GREEN}✓ Omni UI is accessible${NC}"
    else
        echo -e "${RED}✗ Omni UI is not accessible${NC}"
    fi
    
    # Check Matchbox
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8088/boot.ipxe | grep -q "200"; then
        echo -e "${GREEN}✓ Matchbox iPXE endpoint is accessible${NC}"
    else
        echo -e "${RED}✗ Matchbox iPXE endpoint is not accessible${NC}"
    fi
}

# Function to check common issues
check_common_issues() {
    echo -e "\n${YELLOW}Checking for common issues...${NC}"
    
    # Check for port conflicts
    echo -n "Checking for port conflicts... "
    if netstat -tln 2>/dev/null | grep -q ":8080\|:8088\|:8090\|:8095" | grep -v docker; then
        echo -e "${RED}✗ Port conflict detected${NC}"
        echo "  Ports 8080, 8088, 8090, or 8095 are in use by another process"
    else
        echo -e "${GREEN}✓ No port conflicts${NC}"
    fi
    
    # Check disk space
    echo -n "Checking disk space... "
    available=$(df -h . | awk 'NR==2 {print $4}')
    echo -e "${GREEN}✓ Available: $available${NC}"
}

# Main execution
echo -e "\n${YELLOW}1. Checking Docker services...${NC}"
services=("omni" "nginx" "vault-cert-manager" "matchbox" "nginx-reloader")
all_running=true
for service in "${services[@]}"; do
    if ! check_service "$service"; then
        all_running=false
    fi
done

check_network
check_certificates
check_vault
check_endpoints
check_common_issues

echo -e "\n${YELLOW}Summary:${NC}"
if [ "$all_running" = true ]; then
    echo -e "${GREEN}All services are running!${NC}"
else
    echo -e "${RED}Some services are not running. Check the logs above.${NC}"
fi

echo -e "\n${YELLOW}Useful commands:${NC}"
echo "  docker compose logs -f <service>    # Follow logs for a service"
echo "  docker compose restart <service>    # Restart a service"
echo "  docker compose down && docker compose up -d    # Full restart"
echo "  ./clean-restart.sh    # Clean restart (removes data)"