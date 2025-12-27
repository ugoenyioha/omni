# Matchbox Configuration

## Overview

This configuration sets up Matchbox to PXE boot 4 nodes for a Talos Kubernetes cluster managed by Sidero Omni.

## Node Configuration

| Node | UUID | Serial | Role | Hostname |
|------|------|--------|------|----------|
| Curly | 03000200-0400-0500-0006-000700080009 | 0QVNF3GA302961 | Control Plane | curly |
| Larry | 00010203-0405-0607-0809-0a0b0c0d0e0f | 0RFPLBOA302959 | Control Plane | larry |
| Moe | 00010203-0405-0607-0809-0a0b0c0d0e0e | 0QRSITFA302958 | Control Plane | moe |
| Legion | 03000200-0400-0500-0006-000700080007 | 0QPXFWKA302960 | Worker | legion |

### Identification Strategy

The nodes are identified using both UUID and serial number selectors. This ensures consistent identification regardless of which network interface is used for PXE booting. The combination of UUID and serial provides redundancy:
- **UUID**: System UUID from DMI/SMBIOS
- **Serial**: System serial number from DMI/SMBIOS

Both values must match for a node to be selected by a group.

## Directory Structure

```
matchbox/
├── data/
│   ├── groups/           # Node-specific configurations
│   │   ├── controlplane-curly.json
│   │   ├── controlplane-larry.json
│   │   ├── controlplane-moe.json
│   │   └── worker-legion.json
│   ├── profiles/         # Boot profiles
│   │   ├── ipxe.json
│   │   ├── talos-controlplane.json
│   │   └── talos-worker.json
│   └── assets/          # Boot assets
│       ├── ipxe.pxe     # iPXE chainloader
│       └── talos/       # Talos kernel and initramfs
│           ├── vmlinuz-amd64
│           └── initramfs-amd64.xz
└── etc/                 # Matchbox certificates
    ├── ca.crt
    ├── server.crt
    └── server.key
```

## Profiles

### iPXE Profile
Used for initial PXE boot to load iPXE, which then chainloads to Matchbox for the actual boot configuration.

### Talos Profiles
Both control plane and worker profiles use the same kernel arguments with Omni integration:
- `talos.siderolink.api=grpc://omni-siderolink.home.usableapps.io:443`
- `siderolink.api=grpc://omni-siderolink.home.usableapps.io:443`

The configuration is fetched dynamically from Matchbox using node metadata.

## DHCP Configuration

Your DHCP server should be configured to:
1. Provide DHCP option 66 (TFTP server): `192.168.1.8`
2. Provide DHCP option 67 (Boot filename): `ipxe.pxe`

Example dnsmasq configuration:
```
dhcp-boot=ipxe.pxe,matchbox,192.168.1.8
```

## Adding Talos Assets

Download Talos kernel and initramfs to the assets directory:

```bash
# Example for Talos v1.8.1
cd matchbox/data/assets/talos
wget https://github.com/siderolabs/talos/releases/download/v1.8.1/vmlinuz-amd64
wget https://github.com/siderolabs/talos/releases/download/v1.8.1/initramfs-amd64.xz
```

## iPXE Chainloader

Download the iPXE chainloader:
```bash
cd matchbox/data/assets
wget https://boot.ipxe.org/ipxe.pxe
```

## Omni Integration

The Matchbox profiles include the necessary kernel arguments for Omni integration:
- Nodes will automatically register with Omni via SideroLink
- Configuration is managed through Omni's web interface
- No manual Talos configuration files needed

## Testing

1. Ensure all services are running:
   ```bash
   docker-compose ps
   ```

2. Verify Matchbox is accessible:
   ```bash
   curl http://192.168.1.8:8080/
   ```

3. Test with a PXE-capable machine on the same network

## Troubleshooting

### Node Not Booting
1. Check DHCP logs for PXE requests
2. Verify UUID and serial number match exactly
3. Check Matchbox logs: `docker logs matchbox`
4. Boot node and check DMI info: `dmidecode -s system-uuid` and `dmidecode -s system-serial-number`

### Wrong Profile Selected
1. Verify group selector matches node's UUID and serial
2. Check for duplicate UUIDs or serial numbers
3. Review Matchbox debug logs
4. Use Matchbox API to test selectors: `curl http://192.168.1.8:8080/ignition?uuid=<UUID>&serial=<SERIAL>`

### Omni Connection Issues
1. Verify DNS resolution for omni-siderolink.home.usableapps.io
2. Check firewall rules for port 443
3. Ensure Omni service is running