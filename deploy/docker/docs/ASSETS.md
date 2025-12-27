# Matchbox Asset Management

This document explains how Matchbox assets (kernel and initramfs files) are managed in this Sidero Omni deployment.

## Asset Path Structure

Matchbox serves assets from the following directory:
```
matchbox/data/assets/
├── vmlinuz-amd64         # Talos Linux kernel
└── initramfs-amd64.xz    # Talos Linux initramfs
```

## Asset References in Profiles

The Matchbox profiles (`talos-controlplane.json` and `talos-worker.json`) reference these assets with absolute paths:
- Kernel: `/assets/vmlinuz-amd64`
- Initramfs: `/assets/initramfs-amd64.xz`

When served by Matchbox, these files are accessible at:
- `http://matchbox.home.usableapps.io:8080/assets/vmlinuz-amd64`
- `http://matchbox.home.usableapps.io:8080/assets/initramfs-amd64.xz`

## Automatic Asset Download

The `setup.sh` script now automatically downloads the required Talos assets by running `download-talos-assets.sh`.

### Manual Download

If you need to manually download the assets or update to a different Talos version:

```bash
# Set the desired Talos version (default: v1.9.2)
export TALOS_VERSION=v1.9.2

# Run the download script
./download-talos-assets.sh
```

### Download from GitHub

The assets are downloaded from the official Talos Linux GitHub releases:
- Base URL: `https://github.com/siderolabs/talos/releases/download/${TALOS_VERSION}/`

### Supported Architectures

By default, the script downloads AMD64 assets. To download for a different architecture:

```bash
export ARCH=arm64  # or any other supported architecture
./download-talos-assets.sh
```

## Troubleshooting

### Asset Not Found Errors

If you see errors about missing assets during iPXE boot:
1. Check that the assets exist: `ls -la matchbox/data/assets/`
2. Verify file permissions: Files should be readable (644)
3. Check Matchbox logs: `docker logs matchbox`

### Wrong Architecture

If nodes fail to boot, ensure you've downloaded assets for the correct architecture:
- AMD64/x86_64 systems: Use `amd64` assets
- ARM64 systems: Use `arm64` assets

### Network Issues

The assets are served over HTTP (not HTTPS) for iPXE compatibility. Ensure:
- Port 80 is accessible on the Matchbox server
- The nginx proxy correctly forwards requests to Matchbox

## Updating Assets

To update to a new Talos version:

1. Stop the Matchbox container: `docker-compose stop matchbox`
2. Remove old assets: `rm matchbox/data/assets/vmlinuz-* matchbox/data/assets/initramfs-*`
3. Download new assets: `TALOS_VERSION=v1.9.3 ./download-talos-assets.sh`
4. Start Matchbox: `docker-compose start matchbox`

## Asset Serving Path

The nginx configuration proxies asset requests:
- Requests to `http://matchbox.home.usableapps.io/assets/*` → Matchbox container port 8088
- The Matchbox container serves files from `/var/lib/matchbox/assets/`
- This is mapped to the host directory `./matchbox/data/assets/`