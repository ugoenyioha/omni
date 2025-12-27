#!/bin/bash
set -e

# Create macvlan network for Arch Linux
# This gives Omni its own IP address (192.168.1.8) separate from the host

echo "Creating macvlan network for Omni on Arch Linux..."

# Detect the primary network interface
PRIMARY_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)

if [ -z "$PRIMARY_INTERFACE" ]; then
    echo "Error: Could not detect primary network interface"
    echo "Please specify the interface manually in this script"
    exit 1
fi

echo "Detected primary network interface: $PRIMARY_INTERFACE"

# Check if network already exists
if docker network ls | grep -q "omni-macvlan"; then
    echo "Network 'omni-macvlan' already exists"
    read -p "Do you want to recreate it? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Removing existing network..."
        docker network rm omni-macvlan
    else
        echo "Using existing network"
        exit 0
    fi
fi

# Create macvlan network
echo "Creating macvlan network..."
docker network create -d macvlan \
  --subnet=192.168.1.0/24 \
  --gateway=192.168.1.1 \
  --ip-range=192.168.1.8/32 \
  -o parent=$PRIMARY_INTERFACE \
  omni-macvlan

echo "Macvlan network created successfully!"
echo ""
echo "Network details:"
docker network inspect omni-macvlan | grep -E '"Name"|"Subnet"|"Gateway"|"IPRange"|"parent"'

echo ""
echo "IMPORTANT NOTES:"
echo "1. Containers on this network will use IP 192.168.1.8"
echo "2. The host cannot directly communicate with macvlan containers"
echo "3. Access Omni from other machines on the network, not from this host"
echo "4. If you need host access, create a macvlan bridge interface"
echo ""
echo "To create host access (optional):"
echo "  sudo ip link add omni-bridge link $PRIMARY_INTERFACE type macvlan mode bridge"
echo "  sudo ip addr add 192.168.1.100/32 dev omni-bridge"
echo "  sudo ip link set omni-bridge up"
echo "  sudo ip route add 192.168.1.8/32 dev omni-bridge"