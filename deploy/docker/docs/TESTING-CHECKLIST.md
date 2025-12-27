# Sidero Omni Testing Checklist for Shirley (Arch Linux)

## Prerequisites

Before starting the deployment, ensure you have:

- [ ] **Vault AppRole Credentials**
  - [ ] Create `role-id` file with your Vault role ID
  - [ ] Create `secret-id` file with your Vault secret ID
  ```bash
  echo "your-role-id-here" > role-id
  echo "your-secret-id-here" > secret-id
  ```

- [ ] **Network Requirements**
  - [ ] Ensure ports 443 and 80 are available
  - [ ] Verify no conflicts with existing services
  ```bash
  sudo netstat -tlnp | grep -E ':443|:80'
  ```

- [ ] **Docker Requirements**
  - [ ] Docker is installed and running
  - [ ] Docker Compose is installed
  ```bash
  docker --version
  docker-compose --version
  ```

## Deployment Steps

### 1. Create Macvlan Network
```bash
# Run the network creation script
sudo ./create-arch-network.sh

# Verify network was created
docker network ls | grep omni-macvlan
```

### 2. Run Setup Script
```bash
# This will:
# - Validate prerequisites
# - Generate GPG key for Omni
# - Generate Matchbox certificates
# - Download Talos assets
# - Create necessary directories
./setup.sh
```

### 3. Deploy with Docker Compose
```bash
# Use the Arch-specific compose file
docker-compose -f docker-compose-arch.yml up -d

# Check container status
docker-compose -f docker-compose-arch.yml ps
```

### 4. Monitor Startup
```bash
# Watch vault-cert-manager logs (should connect to Vault)
docker-compose -f docker-compose-arch.yml logs -f vault-cert-manager

# Watch nginx logs (should wait for certificates)
docker-compose -f docker-compose-arch.yml logs -f nginx

# Watch omni logs
docker-compose -f docker-compose-arch.yml logs -f omni
```

## Verification Steps

### 1. Check Service Health
```bash
# Check all containers are healthy
docker-compose -f docker-compose-arch.yml ps

# Expected output: All services should be "Up" and "healthy"
```

### 2. Verify Network Access
```bash
# Test Omni UI (should redirect to HTTPS)
curl -I http://192.168.1.8

# Test Omni HTTPS
curl -k https://192.168.1.8

# Test Matchbox
curl -k https://192.168.1.8/matchbox/
```

### 3. Access Web Interfaces
- **Omni UI**: https://omni.home.usableapps.io (or https://192.168.1.8)
- **Matchbox**: https://matchbox.home.usableapps.io/matchbox/

### 4. Verify Certificate Management
```bash
# Check if Vault certificates were created
ls -la nginx/ssl/

# Check certificate details
openssl x509 -in nginx/ssl/server.crt -text -noout | grep -E "Subject:|Not After"
```

### 5. Test Matchbox PXE Assets
```bash
# Verify Talos assets are available
curl -k https://192.168.1.8/assets/vmlinuz-amd64
curl -k https://192.168.1.8/assets/initramfs-amd64.xz
```

## Troubleshooting

### Container Won't Start
```bash
# Check detailed logs
docker-compose -f docker-compose-arch.yml logs [service-name]

# Common issues:
# - Missing role-id/secret-id files
# - Port conflicts
# - Network not created
```

### Certificate Issues
```bash
# Check vault-cert-manager logs
docker-compose -f docker-compose-arch.yml logs vault-cert-manager

# Manually trigger certificate fetch
docker-compose -f docker-compose-arch.yml exec vault-cert-manager /vault-cert-manager.sh fetch
```

### Network Issues
```bash
# Verify macvlan network
docker network inspect omni-macvlan

# Check IP assignment
docker-compose -f docker-compose-arch.yml exec nginx ip addr
```

## Cleanup (if needed)
```bash
# Stop all services
docker-compose -f docker-compose-arch.yml down

# Remove network
docker network rm omni-macvlan

# Clean up data (careful!)
# rm -rf omni-data matchbox nginx
```

## Next Steps

Once everything is verified working:
1. Configure your DHCP server to point to Matchbox for PXE
2. Test PXE booting a node
3. Verify node appears in Omni dashboard
4. Create your first Talos cluster!