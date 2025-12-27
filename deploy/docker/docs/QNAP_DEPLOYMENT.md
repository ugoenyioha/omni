# Sidero Omni QNAP Container Station Deployment

This guide explains how to deploy Sidero Omni with Matchbox on QNAP Container Station.

## Prerequisites

- QNAP NAS with Container Station installed
- SSH access to QNAP (for initial setup)
- DNS entries pointing to 192.168.1.8:
  - `omni.home.usableapps.io`
  - `omni-siderolink.home.usableapps.io`
  - `omni-k8s.home.usableapps.io`
  - `matchbox.home.usableapps.io`
- IP address 192.168.1.8 available (not in DHCP range)

## Directory Structure

```
omni-docker/
├── docker-compose-qnap.yml   # Main compose file for QNAP
├── setup-qnap.sh            # Setup script
├── omni.asc                 # GPG key (generated)
├── .env                     # Environment variables
├── ssl/                     # SSL certificates
│   ├── omni.crt
│   └── omni.key
├── nginx/                   # Nginx configuration
│   ├── omni-qnap.conf
│   └── default.conf
└── matchbox/               # Matchbox configuration
    ├── etc/                # TLS certificates
    │   ├── ca.crt
    │   ├── server.crt
    │   └── server.key
    └── data/               # Matchbox data
        ├── profiles/
        ├── groups/
        └── assets/

```

## Deployment Steps

### 1. Create macvlan network via SSH

Since Container Station doesn't show network options, create it via SSH:

```bash
# SSH into your QNAP
ssh admin@qnap

# Make the script executable
chmod +x /share/Container/omni-docker/create-qnap-network.sh

# Run the network creation script
/share/Container/omni-docker/create-qnap-network.sh
```

This creates a macvlan network with IP 192.168.1.8 reserved for Omni.

### 2. Prepare the deployment package on your workstation

```bash
# Run the setup script
chmod +x setup-qnap.sh
./setup-qnap.sh

# The script will:
# - Ask for your QNAP IP address
# - Generate GPG key if needed
# - Update configuration files
```

### 3. Setup Vault authentication for certificates

```bash
# Run the Vault authentication setup
chmod +x setup-vault-auth.sh
./setup-vault-auth.sh

# This will:
# - Authenticate to Vault
# - Create a renewable token for the certificate manager
# - Test certificate issuance
# - Create vault-token file for Docker
```

### 4. Copy Matchbox certificates

```bash
# Copy the existing Matchbox TLS certificates
cp ../matchbox/certs/{ca.crt,server.crt,server.key} matchbox/etc/
```

### 5. Upload to QNAP

```bash
# Build the certificate manager image first
docker build -t omni-vault-cert-manager:latest -f vault-cert-manager/Dockerfile .

# Save the image
docker save omni-vault-cert-manager:latest | gzip > vault-cert-manager.tar.gz

# Create a compressed archive
tar -czf omni-docker-qnap.tar.gz \
  docker-compose-qnap-macvlan.yml \
  omni.asc \
  .env \
  vault-token \
  nginx/ \
  matchbox/ \
  vault-cert-manager.tar.gz

# Also upload the network creation script
scp create-qnap-network.sh admin@qnap:/share/Container/omni-docker/

# Upload the main archive
scp omni-docker-qnap.tar.gz admin@qnap:/share/Container/
```

### 6. Prepare on QNAP

SSH into your QNAP:

```bash
ssh admin@qnap
cd /share/Container/
tar -xzf omni-docker-qnap.tar.gz
cd omni-docker

# Create the macvlan network first
./create-qnap-network.sh

# Load the certificate manager image
docker load < vault-cert-manager.tar.gz

# Download Talos assets
cd matchbox
./download-talos.sh v1.9.0
cd ..
```

### 7. Import in Container Station

1. Open QNAP Container Station web interface
2. Go to "Create" → "Create Application"
3. Choose "Create docker-compose.yml"
4. Name: "Sidero-Omni"
5. Upload or paste the `docker-compose-qnap-macvlan.yml` content
6. Click "Create"

### 8. Configure Container Station

After creation, you may need to:

1. **Adjust network settings**: 
   - Ensure the containers can communicate
   - Map ports if needed

2. **Configure volumes**:
   - The compose file uses named volumes
   - You can map these to specific QNAP shares if needed

3. **Set resource limits**:
   - CPU and memory limits can be adjusted in Container Station

## Post-Deployment Configuration

### 1. Update DNS

With macvlan, all services use the dedicated IP 192.168.1.8:
- `omni.home.usableapps.io` → 192.168.1.8
- `omni-siderolink.home.usableapps.io` → 192.168.1.8
- `omni-k8s.home.usableapps.io` → 192.168.1.8
- `matchbox.home.usableapps.io` → 192.168.1.8

### 2. Configure WSO2IS

Update the SAML application in WSO2IS with the new URLs:
- Entity ID: `https://omni.home.usableapps.io/saml/metadata`
- ACS URL: `https://omni.home.usableapps.io/saml/acs`

### 3. Configure dnsmasq

Update dnsmasq to point to the QNAP Matchbox instance:
```
dhcp-match=set:ipxe,option:user-class,iPXE
dhcp-boot=tag:ipxe,http://matchbox.home.usableapps.io/boot.ipxe
```

## Accessing Services

- **Omni Web UI**: https://omni.home.usableapps.io (port 443)
- **SideroLink API**: https://omni-siderolink.home.usableapps.io (port 443)
- **Kubernetes Proxy**: https://omni-k8s.home.usableapps.io (port 443)
- **Matchbox**: https://matchbox.home.usableapps.io (port 443)
  - PXE boot: http://matchbox.home.usableapps.io/boot.ipxe (port 80)
- **WireGuard**: 192.168.1.8:50180

## Troubleshooting

### Check container logs in Container Station
1. Go to Container Station
2. Click on the Sidero-Omni application
3. View logs for each container

### Common Issues

1. **Macvlan connectivity issues**:
   - QNAP host cannot directly access containers on macvlan
   - Test from another device on the network
   - Verify IP 192.168.1.8 is not in use: `ping 192.168.1.8`

2. **TUN device access**:
   - QNAP Container Station should handle device access automatically
   - If issues persist, check Container Station privileges

3. **SSL certificate errors**:
   - Check vault-cert-manager logs: `docker logs vault-cert-manager`
   - Ensure Vault token is valid and has proper permissions
   - Verify network connectivity to Vault from QNAP

## Backup

Important data to backup:
- `/share/Container/omni-docker/omni.asc` - GPG encryption key
- `/share/Container/omni-docker/vault-token` - Vault authentication token
- Omni data volume
- Matchbox data volume

## Updates

To update containers:
1. Stop the application in Container Station
2. Update image versions in docker-compose-qnap-macvlan.yml
3. Recreate the application