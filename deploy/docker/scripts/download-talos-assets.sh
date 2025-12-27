#!/bin/bash
set -e

# Configuration
TALOS_VERSION="${TALOS_VERSION:-v1.9.2}"
ARCH="${ARCH:-amd64}"
ASSETS_DIR="matchbox/data/assets"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Downloading Talos Linux assets for Matchbox...${NC}"
echo "Talos version: ${TALOS_VERSION}"
echo "Architecture: ${ARCH}"

# Create assets directory if it doesn't exist
mkdir -p "${ASSETS_DIR}"

# Base URL for Talos assets
BASE_URL="https://github.com/siderolabs/talos/releases/download/${TALOS_VERSION}"

# Assets to download
KERNEL="vmlinuz-${ARCH}"
INITRAMFS="initramfs-${ARCH}.xz"

# Download kernel
echo -e "\n${YELLOW}Downloading kernel...${NC}"
if [ -f "${ASSETS_DIR}/${KERNEL}" ]; then
    echo "Kernel already exists, skipping download"
else
    wget -q --show-progress -O "${ASSETS_DIR}/${KERNEL}" "${BASE_URL}/${KERNEL}"
    echo -e "${GREEN}✓ Kernel downloaded${NC}"
fi

# Download initramfs
echo -e "\n${YELLOW}Downloading initramfs...${NC}"
if [ -f "${ASSETS_DIR}/${INITRAMFS}" ]; then
    echo "Initramfs already exists, skipping download"
else
    wget -q --show-progress -O "${ASSETS_DIR}/${INITRAMFS}" "${BASE_URL}/${INITRAMFS}"
    echo -e "${GREEN}✓ Initramfs downloaded${NC}"
fi

# Verify files exist and are not empty
echo -e "\n${YELLOW}Verifying downloaded assets...${NC}"
for file in "${KERNEL}" "${INITRAMFS}"; do
    if [ ! -f "${ASSETS_DIR}/${file}" ]; then
        echo -e "${RED}Error: ${file} not found!${NC}"
        exit 1
    fi
    
    size=$(stat -f%z "${ASSETS_DIR}/${file}" 2>/dev/null || stat -c%s "${ASSETS_DIR}/${file}" 2>/dev/null)
    if [ "$size" -eq 0 ]; then
        echo -e "${RED}Error: ${file} is empty!${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ ${file} ($(numfmt --to=iec-i --suffix=B $size))${NC}"
done

# Set proper permissions
chmod 644 "${ASSETS_DIR}/${KERNEL}" "${ASSETS_DIR}/${INITRAMFS}"

echo -e "\n${GREEN}Talos assets successfully downloaded to ${ASSETS_DIR}/${NC}"
echo -e "${GREEN}The assets will be served by Matchbox at:${NC}"
echo "  - http://matchbox.home.usableapps.io/assets/${KERNEL}"
echo "  - http://matchbox.home.usableapps.io/assets/${INITRAMFS}"
echo "  - https://192.168.1.8/assets/${KERNEL}"
echo "  - https://192.168.1.8/assets/${INITRAMFS}"