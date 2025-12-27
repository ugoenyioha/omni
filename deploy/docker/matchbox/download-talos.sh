#!/bin/bash
set -e

TALOS_VERSION=${1:-v1.9.0}
ASSETS_DIR="data/assets/talos"

echo "Downloading Talos $TALOS_VERSION assets..."

mkdir -p "$ASSETS_DIR"

# Download Talos kernel and initramfs
echo "Downloading vmlinuz..."
curl -L -o "$ASSETS_DIR/vmlinuz" \
  "https://github.com/siderolabs/talos/releases/download/$TALOS_VERSION/vmlinuz-amd64"

echo "Downloading initramfs.xz..."
curl -L -o "$ASSETS_DIR/initramfs.xz" \
  "https://github.com/siderolabs/talos/releases/download/$TALOS_VERSION/initramfs-amd64.xz"

echo "Talos assets downloaded successfully to $ASSETS_DIR"
ls -la "$ASSETS_DIR"