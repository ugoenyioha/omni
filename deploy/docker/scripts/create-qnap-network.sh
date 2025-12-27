#!/bin/bash
set -e

echo "Creating macvlan network for Sidero Omni on QNAP"
echo "================================================"

# Check if docker is available
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker command not found. Please SSH into your QNAP to run this script."
    exit 1
fi

# Check if network already exists
if docker network ls | grep -q "omni-macvlan"; then
    echo "Network 'omni-macvlan' already exists."
    echo "To recreate, first run: docker network rm omni-macvlan"
    exit 0
fi

# Detect the primary network interface
echo "Detecting network interface..."
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
if [ -z "$INTERFACE" ]; then
    INTERFACE="eth0"  # Fallback to eth0
fi
echo "Using interface: $INTERFACE"

# Get current network information
SUBNET=$(ip -4 addr show $INTERFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+' | head -n1)
GATEWAY=$(ip route | grep default | awk '{print $3}' | head -n1)

echo "Network configuration:"
echo "  Subnet: ${SUBNET:-192.168.1.0/24}"
echo "  Gateway: ${GATEWAY:-192.168.1.1}"
echo "  Reserved IP: 192.168.1.8"

# Create macvlan network
echo ""
echo "Creating macvlan network..."
docker network create -d macvlan \
  --subnet=${SUBNET:-192.168.1.0/24} \
  --gateway=${GATEWAY:-192.168.1.1} \
  --ip-range=192.168.1.8/32 \
  -o parent=$INTERFACE \
  omni-macvlan

if [ $? -eq 0 ]; then
    echo "✓ Successfully created macvlan network 'omni-macvlan'"
    echo ""
    echo "Network details:"
    docker network inspect omni-macvlan --format '{{json .}}' | jq '{Name, Driver, IPAM}'
else
    echo "✗ Failed to create network"
    exit 1
fi

echo ""
echo "Next steps:"
echo "1. Update docker-compose-qnap-macvlan.yml to use 'omni-macvlan' network"
echo "2. Deploy using: docker-compose -f docker-compose-qnap-macvlan.yml up -d"