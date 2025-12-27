# Omni-Docker Deployment Guide

This guide provides step-by-step instructions for deploying Sidero Omni with Matchbox PXE boot server.

## Prerequisites

- Docker and Docker Compose installed
- Access to Vault server with AppRole authentication
- Network access to create macvlan network
- Sufficient disk space for Talos assets (~100MB)

## Deployment Steps

### 1. Clone or Copy the Repository

```bash
# For remote deployment (e.g., to Shirley)
rsync -av omni-docker/ user@remote-host:/path/to/omni-docker/
```

### 2. Create Macvlan Network

Choose the appropriate script for your platform:

```bash
# For Arch Linux
./create-arch-network.sh

# For QNAP
./create-qnap-network.sh
```

### 3. Generate Matchbox Certificates

```bash
./generate-matchbox-certs.sh
```

### 4. Configure Vault Authentication

Create the AppRole credentials:

```bash
# If you have Vault root token, generate credentials:
export VAULT_TOKEN=<your-root-token>
export VAULT_ADDR=https://vault.home.usableapps.io
export VAULT_NAMESPACE=admin

# Get role-id
vault read -field=role_id auth/approle/role/cert-manager/role-id > role-id

# Get secret-id
vault write -field=secret_id -f auth/approle/role/cert-manager/secret-id > secret-id
```

### 5. Generate Omni GPG Key

If not already present:

```bash
# Create GPG key configuration
cat > omni-key-full.txt <<EOF
%echo Generating Omni GPG key
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: Omni
Name-Comment: Used for etcd data encryption
Name-Email: omni@home.usableapps.io
Expire-Date: 0
%commit
%echo done
EOF

# Generate key
gpg --batch --generate-key omni-key-full.txt
gpg --armor --export-secret-keys omni@home.usableapps.io > omni.asc
```

### 6. Download Talos Assets

```bash
./download-talos-assets.sh
```

### 7. Deploy Services

```bash
# For Arch Linux
docker compose -f docker-compose-arch.yml up -d

# For QNAP
docker compose -f docker-compose-qnap.yml up -d
```

### 8. Verify Deployment

```bash
# Run troubleshooting script
./troubleshoot.sh

# Check service status
docker compose ps

# View logs
docker compose logs -f
```

## Access Points

- **Omni UI**: https://omni.home.usableapps.io/ or https://192.168.1.8/
- **Kubernetes Proxy**: https://omni-k8s.home.usableapps.io/
- **Siderolink**: https://omni-siderolink.home.usableapps.io/
- **Matchbox Assets**: https://matchbox.home.usableapps.io/assets/
- **iPXE Boot**: http://matchbox.home.usableapps.io/boot.ipxe

## Common Issues and Solutions

### 1. Certificate Not Found
- Check vault-cert-manager logs: `docker logs vault-cert-manager`
- Verify Vault connectivity and AppRole credentials
- Ensure PKI path exists in Vault

### 2. Port Already in Use
- Check for conflicting services
- Modify port mappings in docker-compose if needed

### 3. Macvlan IP Conflict
- Ensure IP 192.168.1.8 is not in use
- Check DHCP server configuration to exclude this IP

### 4. Omni Restart Loop
- Check for siderolink binding issues
- Perform clean restart: `./clean-restart.sh`

### 5. Matchbox Not Serving Assets
- Verify assets exist in matchbox/data/assets/
- Check Matchbox logs for errors
- Ensure nginx is proxying correctly

## Maintenance

### Certificate Renewal
Certificates are automatically renewed by vault-cert-manager. Default renewal is 7 days before expiry.

### Updating Services
```bash
# Update specific service
docker compose pull <service>
docker compose up -d <service>

# Update all services
docker compose pull
docker compose up -d
```

### Backup
Important data to backup:
- `data/` - Omni data and etcd
- `matchbox/data/` - Matchbox profiles and groups
- `omni.asc` - GPG key for etcd encryption
- `role-id` and `secret-id` - Vault credentials

## Security Notes

1. The macvlan network exposes services directly to your network
2. Ensure firewall rules are properly configured
3. Regularly update container images
4. Monitor certificate expiration
5. Secure Vault AppRole credentials