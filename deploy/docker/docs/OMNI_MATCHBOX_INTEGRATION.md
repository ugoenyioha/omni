# Omni and Matchbox Integration Guide

## Overview

Omni uses Matchbox as a PXE boot server to automatically provision bare metal machines with Talos Linux. The integration enables:
- Zero-touch provisioning of new machines
- Secure machine registration via SideroLink
- Centralized upgrade management
- Real-time log and event streaming

## How It Works

### 1. Boot Process Flow

```
Machine PXE Boot → DHCP (dnsmasq) → Matchbox → Talos Kernel → SideroLink → Omni Registration
```

### 2. Key Components

#### SideroLink
- Secure WireGuard tunnel between each machine and Omni
- Provides encrypted, authenticated communication
- Enables real-time kernel logs and event streaming
- Each machine gets unique IPv6 address and WireGuard keys

#### Kernel Parameters
The three critical parameters that link machines to your Omni instance:
- `siderolink.api` - SideroLink API endpoint
- `talos.events.sink` - Event collection endpoint  
- `talos.logging.kernel` - Kernel log streaming endpoint

### 3. Getting Kernel Parameters from Omni

1. Access Omni dashboard at https://omni.home.usableapps.io
2. Click "Copy Kernel Parameters" button
3. You'll get parameters like:
   ```
   siderolink.api=grpc://192.168.1.8:8090?jointoken=<token>
   talos.events.sink=[fdae:41e4:649b:9303::1]:8090
   talos.logging.kernel=tcp://[fdae:41e4:649b:9303::1]:8092
   ```

### 4. Updating Matchbox Profile

Update `/Users/uenyioha/Documents/code/shirley/sidero/omni-docker/matchbox/data/profiles/talos.json`:

```json
{
  "id": "talos",
  "name": "Talos Linux for Omni",
  "boot": {
    "kernel": "/assets/talos/vmlinuz",
    "initrd": ["/assets/talos/initramfs.xz"],
    "args": [
      "initrd=initramfs.xz",
      "init_on_alloc=1",
      "slab_nomerge",
      "pti=on",
      "console=tty0",
      "console=ttyS0", 
      "printk.devkmsg=on",
      "talos.platform=metal",
      "siderolink.api=grpc://192.168.1.8:8090?jointoken=<your-token>",
      "talos.events.sink=[fdae:41e4:649b:9303::1]:8090",
      "talos.logging.kernel=tcp://[fdae:41e4:649b:9303::1]:8092"
    ]
  }
}
```

### 5. Machine Registration Process

1. **PXE Boot**: Machine boots and receives iPXE script from dnsmasq
2. **Matchbox**: Serves kernel, initramfs, and parameters
3. **Talos Boot**: Kernel boots with Omni parameters
4. **SideroLink Connection**: Machine establishes WireGuard tunnel
5. **Registration**: Machine appears in Omni dashboard
6. **Allocation**: Assign machine to a cluster or leave unallocated

### 6. Upgrade Management

#### Automatic Upgrades via Omni

1. **Cluster-wide Upgrades**:
   - Navigate to cluster in Omni
   - Click "Upgrade Kubernetes" or "Upgrade Talos"
   - Select target version
   - Omni orchestrates rolling upgrade

2. **Machine-specific Upgrades**:
   - Select machine in Omni
   - Choose "Upgrade Talos" 
   - Applies upgrade via SideroLink

#### Upgrade Process:
1. Omni pushes upgrade command via SideroLink
2. Machine downloads new Talos image
3. Applies upgrade and reboots
4. Reconnects to Omni with new version
5. Omni tracks upgrade progress

### 7. Talos Version Management

Matchbox serves specific Talos versions:
- Store different versions in `/var/lib/matchbox/assets/talos/`
- Create version-specific profiles
- Omni handles version selection during upgrades

Example structure:
```
/var/lib/matchbox/assets/talos/
├── v1.9.0/
│   ├── vmlinuz
│   └── initramfs.xz
├── v1.8.0/
│   ├── vmlinuz
│   └── initramfs.xz
```

### 8. Network Requirements

- **Port 50180/UDP**: WireGuard (SideroLink)
- **Port 443/TCP**: HTTPS for all web services (Omni, Matchbox UI)
- **Port 80/TCP**: HTTP for iPXE boot only (auto-redirects to HTTPS for browsers)
- **Port 67/68**: DHCP/PXE

### 9. Security Considerations

- SideroLink provides encrypted communication
- Each machine has unique WireGuard keys
- Join tokens authenticate new machines
- No credentials stored on machines
- All management through secure Omni API

### 10. Troubleshooting

#### Machine Not Appearing in Omni:
1. Check kernel parameters are correct
2. Verify SideroLink ports are accessible
3. Check Omni logs: `docker logs sidero-omni`
4. Verify WireGuard connectivity

#### Upgrade Failures:
1. Check SideroLink connection
2. Verify target version compatibility
3. Check machine has internet access
4. Review Talos logs in Omni dashboard

### 11. Best Practices

1. **Version Alignment**: Keep Matchbox assets aligned with Omni-supported versions
2. **Parameter Updates**: Regenerate kernel parameters if Omni is redeployed
3. **Network Stability**: Ensure reliable connectivity for SideroLink
4. **Monitoring**: Watch Omni dashboard during provisioning/upgrades
5. **Backup**: Keep machine configurations backed up in Omni