# Omni + Matchbox + Nginx Docker Deployment

This directory contains a complete deployment configuration for running Sidero Omni with Matchbox PXE boot server and Nginx reverse proxy as a unified stack.

## Architecture

```
Internet/LAN (192.168.1.8 via macvlan)
         │
         ▼
┌─────────────────────────────────────────┐
│              Nginx                      │
│  ├─ :443 → Omni (HTTPS/gRPC)            │
│  ├─ :443 → Matchbox (HTTPS)             │
│  ├─ :80  → Matchbox (iPXE boot)         │
│  └─ :50180/UDP → Omni (WireGuard)       │
└─────────────────────────────────────────┘
         │
    ┌────┴────┬─────────────┐
    ▼         ▼             ▼
┌───────┐ ┌─────────┐ ┌───────────┐
│ Omni  │ │Matchbox │ │   etcd    │
└───────┘ └─────────┘ └───────────┘
```

## Directory Structure

```
deploy/docker/
├── docker-compose.yml           # Main compose (Arch Linux)
├── docker-compose-qnap.yml      # QNAP NAS variant
├── omni-config.yaml             # Omni runtime config
├── .env.example                 # Environment template
├── nginx/                       # Reverse proxy
│   ├── Dockerfile
│   ├── omni.conf                # Main nginx config
│   └── wait-for-certs.sh
├── letsencrypt-cert-manager/    # Automatic SSL via Cloudflare
│   ├── Dockerfile
│   └── letsencrypt-cert-manager.sh
├── nginx-reloader/              # Hot certificate reload
│   ├── Dockerfile
│   └── reload-watcher.sh
├── ddns-updater/                # Dynamic DNS updates
│   ├── Dockerfile
│   └── ddns-updater.sh
├── matchbox/                    # PXE boot server
│   ├── data/groups/             # Machine group configs
│   ├── data/profiles/           # Boot profiles
│   └── etc/                     # Certificates (not in git)
├── scripts/                     # Helper scripts
└── docs/                        # Detailed documentation
```

## Quick Start

### 1. Clone and Configure

```bash
cd deploy/docker

# Copy environment template
cp .env.example .env

# Edit with your Cloudflare credentials and settings
vim .env
```

### 2. Create macvlan Network

```bash
# For standard Linux
./scripts/create-arch-network.sh

# For QNAP NAS (via SSH)
./scripts/create-qnap-network.sh
```

### 3. Generate Certificates

**Matchbox TLS certificates** (for gRPC):
```bash
cd matchbox/etc
# Generate CA
openssl genrsa -out ca.key 4096
openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 \
    -out ca.crt -subj "/CN=matchbox-ca"

# Generate server cert
openssl genrsa -out server.key 4096
openssl req -new -key server.key -out server.csr \
    -subj "/CN=matchbox.home.usableapps.io"
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key \
    -CAcreateserial -out server.crt -days 3650 -sha256
```

**Omni GPG key** (for etcd encryption):
```bash
gpg --batch --generate-key <<EOF
Key-Type: RSA
Key-Length: 4096
Name-Real: Omni
Name-Email: omni@yourdomain.com
Expire-Date: 0
%commit
EOF
gpg --armor --export-secret-keys omni@yourdomain.com > omni.asc
```

### 4. Configure DNS

Point these domains to your macvlan IP (e.g., 192.168.1.8):
- `omni.yourdomain.com` - Main UI/API
- `omni-k8s.yourdomain.com` - Kubernetes proxy
- `omni-siderolink.yourdomain.com` - Machine API
- `matchbox.yourdomain.com` - PXE boot server

### 5. Deploy

```bash
# Standard deployment
docker compose up -d

# QNAP deployment
docker compose -f docker-compose-qnap.yml up -d
```

### 6. Verify

```bash
# Check services
docker compose ps

# View logs
docker compose logs -f

# Run troubleshooting
./scripts/troubleshoot.sh
```

## Push-to-Matchbox Integration

This Omni build includes the **push-to-matchbox** feature. From the Omni UI:

1. Go to **Download Installation Media**
2. Configure your schematic (extensions, kernel args, etc.)
3. Click **Push to Matchbox**

This automatically:
- Creates the schematic via Image Factory
- Downloads kernel and initramfs
- Creates Matchbox profiles for controlplane/worker
- Optionally updates existing machine groups

## Services Overview

| Service | Port | Purpose |
|---------|------|---------|
| Omni | 8080 | Main API and Web UI |
| Omni | 8095 | Kubernetes Proxy |
| Omni | 8091 | SideroLink gRPC |
| Omni | 50180/UDP | WireGuard tunnel |
| Matchbox | 8088 | HTTP (iPXE boot) |
| Matchbox | 8081 | gRPC API |
| Nginx | 443 | HTTPS reverse proxy |
| Nginx | 80 | HTTP (iPXE redirect) |
| etcd | 2379 | Omni state storage |

## Configuration Files

### omni-config.yaml
Runtime configuration for Omni including:
- Matchbox paths for push-to-matchbox feature
- Auth token settings
- OIDC configuration

### nginx/omni.conf
Nginx reverse proxy configuration with:
- gRPC passthrough for all Omni services
- WebSocket support
- Matchbox HTTP/HTTPS proxying
- Long timeouts for streaming connections

### .env
Environment variables for:
- Cloudflare API credentials (SSL certificates)
- DDNS configuration
- Let's Encrypt settings

## Updating

```bash
# Pull latest images
docker compose pull

# Recreate containers
docker compose up -d

# Or update specific service
docker compose up -d omni
```

## Backup

Critical files to backup:
- `omni.asc` - GPG key for etcd encryption
- `matchbox/etc/*.key` - TLS private keys
- `.env` - API credentials
- `data/` - Omni persistent data (if using bind mounts)

## Documentation

See `docs/` directory for detailed guides:
- `DEPLOYMENT_GUIDE.md` - Full deployment walkthrough
- `QNAP_DEPLOYMENT.md` - QNAP-specific instructions
- `MATCHBOX_CONFIGURATION.md` - PXE boot setup
- `CERTIFICATE_ARCHITECTURE.md` - SSL/TLS details
