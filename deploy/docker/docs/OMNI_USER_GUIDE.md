# Sidero Omni User Guide

## Overview

This guide covers how to use Sidero Omni to manage Talos Linux clusters after deployment. Omni provides a web-based interface for complete cluster lifecycle management.

## Accessing Omni

1. Open your browser to: https://omni.home.usableapps.io
2. Login with SAML authentication via WSO2 Identity Server
3. Authorized user: admin@home.usableapps.io

## Initial Setup

### 1. Verify Services

All services should be running on 192.168.1.8:
- Omni UI: https://omni.home.usableapps.io
- Kubernetes API Proxy: https://omni-k8s.home.usableapps.io
- SideroLink: https://omni-siderolink.home.usableapps.io
- Matchbox: http://matchbox.home.usableapps.io

### 2. Download Boot Assets

```bash
# Download Talos kernel and initramfs
cd matchbox/data/assets/talos
wget https://github.com/siderolabs/talos/releases/download/v1.8.1/vmlinuz-amd64
wget https://github.com/siderolabs/talos/releases/download/v1.8.1/initramfs-amd64.xz

# Download iPXE chainloader
cd ../
wget https://boot.ipxe.org/ipxe.pxe
```

## Creating Your First Cluster

### 1. Machine Registration

Your 4 nodes will automatically register when PXE booted:
- **Curly** (Control Plane): UUID 03000200-0400-0500-0006-000700080009
- **Larry** (Control Plane): UUID 00010203-0405-0607-0809-0a0b0c0d0e0f
- **Moe** (Control Plane): UUID 00010203-0405-0607-0809-0a0b0c0d0e0e
- **Legion** (Worker): UUID 03000200-0400-0500-0006-000700080007

### 2. PXE Boot Process

1. Configure DHCP to point to Matchbox (192.168.1.8)
2. Power on machines with PXE boot enabled
3. Machines will:
   - Boot iPXE chainloader
   - Request configuration from Matchbox
   - Boot Talos with SideroLink parameters
   - Register with Omni automatically

### 3. Create Cluster in Omni

1. Navigate to **Clusters** → **Create Cluster**
2. Configure cluster settings:
   - **Name**: Choose a cluster name
   - **Kubernetes Version**: Select desired version
   - **Talos Version**: Select compatible version

3. Machine allocation:
   - Select registered machines from inventory
   - Assign roles (control plane/worker)
   - Omni respects the Matchbox group assignments

4. Network configuration:
   - Default CNI: Flannel (can be changed to Cilium later)
   - Configure pod/service CIDRs if needed

5. Click **Create Cluster**

## Cluster Operations

### Installing Cilium (Optional)

If you prefer Cilium over the default Flannel:

1. In Omni, navigate to your cluster
2. Go to **Config Patches**
3. Create a new patch to disable default CNI:
   ```yaml
   cluster:
     network:
       cni:
         name: none
   ```
4. Apply to all machines
5. Once cluster is ready, install Cilium:
   ```bash
   # Download kubeconfig from Omni
   kubectl apply -f https://docs.cilium.io/en/stable/examples/kubernetes/cilium.yaml
   ```

### Accessing Kubernetes

1. Download kubeconfig from Omni:
   - Navigate to your cluster
   - Click **Download Kubeconfig**
   
2. Use kubectl:
   ```bash
   export KUBECONFIG=~/Downloads/my-cluster-kubeconfig
   kubectl get nodes
   ```

3. Or use the Kubernetes proxy:
   ```bash
   # Configure kubectl to use Omni's proxy
   kubectl config set-cluster my-cluster \
     --server=https://omni-k8s.home.usableapps.io \
     --certificate-authority=path/to/ca.crt
   ```

### Managing Machines

#### Add New Machines
1. PXE boot the new machine
2. It appears in Omni's machine inventory
3. Add to existing cluster or create new one

#### Remove Machines
1. Select machine in Omni
2. Click **Remove from Cluster**
3. Machine returns to inventory for reuse

#### Wipe Machine
1. Select machine
2. Click **Wipe**
3. Confirms complete data removal

### Cluster Upgrades

1. Navigate to your cluster
2. Click **Upgrade**
3. Select new Talos/Kubernetes versions
4. Omni performs rolling upgrade automatically

### Scaling Operations

#### Scale Up
1. Select available machines from inventory
2. Add to cluster with appropriate role

#### Scale Down
1. Remove worker nodes first
2. Maintain odd number of control planes
3. Minimum 1 control plane required

## Monitoring and Troubleshooting

### Machine Status

In Omni's machine view:
- **Green**: Healthy and connected
- **Yellow**: Degraded or updating
- **Red**: Disconnected or failed

### View Logs

1. Select a machine
2. Click **Console** for real-time logs
3. Use **dmesg** tab for kernel logs

### Common Issues

#### Machine Not Appearing
- Verify PXE boot succeeded
- Check Matchbox logs: `docker logs matchbox`
- Verify UUID/serial match group selectors
- Check network connectivity to SideroLink

#### Cluster Creation Fails
- Ensure minimum 1 control plane selected
- Verify machines are healthy
- Check for IP conflicts
- Review Omni logs

#### Certificate Issues
- Verify Vault cert-manager is running
- Check certificate expiry
- Ensure DNS resolution works

## Best Practices

1. **Cluster Sizing**
   - Use 3 control planes for HA
   - Odd numbers prevent split-brain
   - Separate worker nodes for workloads

2. **Updates**
   - Test upgrades in staging first
   - Upgrade during maintenance windows
   - Keep Talos and Kubernetes versions compatible

3. **Backup**
   - Omni backs up etcd automatically
   - Download backups regularly
   - Test restore procedures

4. **Security**
   - Limit Omni access to administrators
   - Use SAML/OIDC authentication
   - Regular certificate rotation via Vault

## Integration with CI/CD

### GitOps with Flux/ArgoCD
1. Download kubeconfig from Omni
2. Install GitOps operator
3. Point to your Git repository
4. Omni manages infrastructure, GitOps manages apps

### API Access
Omni provides APIs for automation:
- Machine management
- Cluster operations
- Configuration updates

## Disaster Recovery

### Cluster Recovery
1. If all control planes fail:
   - Boot new machines via PXE
   - Restore from Omni's etcd backup
   - Rejoin worker nodes

### Omni Recovery
1. Restore from volume backups:
   - `data/` - Omni state and etcd
   - `_out/` - Generated configs
2. Machines reconnect automatically

## Advanced Configuration

### Custom Machine Classes
Create machine classes for different hardware:
1. Go to **Machine Classes**
2. Define CPU, memory, storage requirements
3. Apply to machine groups

### Config Patches
Apply custom Talos configuration:
1. Navigate to **Config Patches**
2. Create YAML patches
3. Target specific machines or roles

### Extensions
Install Talos system extensions:
1. Add to machine config patches
2. Examples: gvisor, nvidia-driver
3. Applied during boot/upgrade

## Support and Resources

- **Omni Documentation**: https://omni.siderolabs.com/docs
- **Talos Documentation**: https://talos.dev/docs
- **Community Slack**: https://slack.dev.talos-systems.io
- **GitHub Issues**: https://github.com/siderolabs/omni/issues