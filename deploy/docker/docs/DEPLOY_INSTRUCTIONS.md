# Sidero Omni Docker Deployment Instructions

Complete deployment guide for both Arch Linux and QNAP environments.

## Prerequisites

- Docker and Docker Compose installed
- Access to Vault for certificate management
- Network access on port 192.168.1.8

## Initial Setup (Both Platforms)

1. **Run initial setup to create directories and GPG key:**
```bash
./setup.sh
```
This creates:
- All required directories (data/, _out/, matchbox/data/*, etc.)
- GPG encryption key for Omni's etcd database

2. **Configure Vault authentication:**
```bash
./setup-vault-auth.sh
```
This generates the `vault-token` file for certificate management.

## Arch Linux Deployment

1. **Create macvlan network:**
```bash
./create-arch-network.sh
```

2. **Deploy services:**
```bash
docker-compose -f docker-compose-arch.yml up -d
```

3. **Access services:**
- Omni: https://omni.home.usableapps.io
- Matchbox: https://matchbox.home.usableapps.io

## QNAP Deployment

### Option 1: Automated Deployment
```bash
./deploy-to-qnap.sh
```
This script handles everything including network creation on QNAP.

### Option 2: Manual Deployment

1. **On QNAP, create macvlan network:**
```bash
ssh admin@qnap
docker network create -d macvlan \
  --subnet=192.168.1.0/24 \
  --gateway=192.168.1.1 \
  --ip-range=192.168.1.8/32 \
  -o parent=eth0 \
  omni-macvlan
```

2. **Deploy from local machine:**
```bash
docker-compose -f docker-compose-qnap.yml up -d
```

## Post-Deployment Configuration

1. **Get kernel parameters from Omni:**
   - Access https://omni.home.usableapps.io
   - Click "Copy Kernel Parameters"

2. **Update Matchbox profile:**
```bash
./update-matchbox-profile.sh
```

3. **Configure dnsmasq for PXE boot** (on separate machine)

## Maintenance

### View logs:
```bash
# Arch Linux
docker-compose -f docker-compose-arch.yml logs -f

# QNAP
docker-compose -f docker-compose-qnap.yml logs -f
```

### Update containers manually:
```bash
./update-containers.sh
```

### Restart services:
```bash
# Arch Linux
docker-compose -f docker-compose-arch.yml restart

# QNAP
docker-compose -f docker-compose-qnap.yml restart
```

### Clean deployment:
```bash
# Stop services
docker-compose -f docker-compose-[arch|qnap].yml down

# Remove data (WARNING: This deletes all Omni data!)
rm -rf data _out

# Restart fresh
./setup.sh
docker-compose -f docker-compose-[arch|qnap].yml up -d
```

## Troubleshooting

### Macvlan host access issue:
The host cannot directly access containers on macvlan network. Access from another machine on the network.

### Certificate issues:
Check vault-cert-manager logs:
```bash
docker logs vault-cert-manager
```

### Network not found:
Ensure you ran the appropriate create network script first.

### Directory permissions:
All directories are created by setup.sh with proper permissions. If issues occur, re-run setup.sh.