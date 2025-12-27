# Quick Start Guide

This guide gets you from zero to a running Talos Kubernetes cluster managed by Omni.

## Prerequisites

- Docker and Docker Compose installed
- Access to HashiCorp Vault with appropriate permissions
- Network configured for PXE booting
- 4 bare metal machines (Curly, Larry, Moe, Legion)

## Step 1: Deploy Omni Stack

### On Arch Linux (Shirley)

```bash
# Clone the repository
git clone <repository-url>
cd omni-docker

# Initial setup
./setup.sh

# Configure Vault AppRole
./setup-vault-approle.sh

# Create network
./create-arch-network.sh

# Deploy
docker-compose -f docker-compose-arch.yml up -d
```

### On QNAP NAS

```bash
# Use automated deployment
./deploy-to-qnap.sh
```

## Step 2: Download Boot Assets

```bash
cd matchbox/data/assets

# Download iPXE
wget https://boot.ipxe.org/ipxe.pxe

# Download Talos (example v1.8.1)
mkdir talos && cd talos
wget https://github.com/siderolabs/talos/releases/download/v1.8.1/vmlinuz-amd64
wget https://github.com/siderolabs/talos/releases/download/v1.8.1/initramfs-amd64.xz
```

## Step 3: Configure DHCP/PXE

Add to your dnsmasq configuration:
```
dhcp-boot=ipxe.pxe,matchbox,192.168.1.8
```

Or configure your DHCP server with:
- Next Server: 192.168.1.8
- Boot File: ipxe.pxe

## Step 4: Boot Your Machines

1. Enable PXE boot in BIOS/UEFI
2. Boot machines in this order:
   - Control planes first: Curly, Larry, Moe
   - Worker last: Legion
3. Machines will automatically:
   - PXE boot from Matchbox
   - Download Talos Linux
   - Register with Omni

## Step 5: Create Cluster

1. Access Omni at https://omni.home.usableapps.io
2. Login with admin@home.usableapps.io
3. Go to **Clusters** → **Create Cluster**
4. Configure:
   - Name: `my-cluster`
   - Select all 4 registered machines
   - Assign roles (3 control planes, 1 worker)
5. Click **Create**
6. Wait for cluster to be ready (~5-10 minutes)

## Step 6: Access Your Cluster

1. Download kubeconfig from Omni
2. Use kubectl:
   ```bash
   export KUBECONFIG=~/Downloads/my-cluster-kubeconfig
   kubectl get nodes
   ```

## Verify Everything Works

```bash
# Check all Docker services
docker-compose -f docker-compose-arch.yml ps

# Check Matchbox
curl http://192.168.1.8:8080/

# Check nodes in Omni UI
# Should see 4 machines registered

# After cluster creation
kubectl get nodes
kubectl get pods -A
```

## Next Steps

- Install Cilium CNI if desired (see User Guide)
- Deploy workloads to your cluster
- Configure GitOps with Flux/ArgoCD
- Set up monitoring with Prometheus/Grafana

## Troubleshooting Quick Fixes

**Machines not PXE booting:**
```bash
# Check Matchbox logs
docker logs matchbox

# Verify DHCP/TFTP
tcpdump -i any port 69
```

**Machines not appearing in Omni:**
```bash
# Check SideroLink connectivity
docker logs sidero-omni

# Verify DNS resolution
nslookup omni-siderolink.home.usableapps.io
```

**SSL Certificate issues:**
```bash
# Check cert manager
docker logs vault-cert-manager

# Manually fetch certs
docker exec vault-cert-manager /vault-cert-manager.sh fetch
```

For detailed information, see the [Omni User Guide](OMNI_USER_GUIDE.md).