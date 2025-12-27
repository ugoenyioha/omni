# PXE Boot Testing Guide for Sidero Omni with Matchbox

This guide provides comprehensive instructions for testing PXE boot functionality with your Sidero Omni setup using Matchbox. It covers the complete process from prerequisites through troubleshooting.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Network Configuration Requirements](#network-configuration-requirements)
3. [BIOS/UEFI Settings](#biosuefi-settings)
4. [Step-by-Step Testing Procedure](#step-by-step-testing-procedure)
5. [Verifying Matchbox Services](#verifying-matchbox-services)
6. [Troubleshooting Common Issues](#troubleshooting-common-issues)
7. [Monitoring the Boot Process](#monitoring-the-boot-process)
8. [Verifying Node Registration in Omni](#verifying-node-registration-in-omni)
9. [Node-Specific Testing](#node-specific-testing)

## Prerequisites

Before attempting PXE boot, ensure the following components are in place:

### 1. Infrastructure Requirements

- **Sidero Omni Stack Running**: All containers should be healthy
  ```bash
  docker compose -f docker-compose-qnap.yml ps
  ```
  Expected output should show all services as "Up" and healthy.

- **Network Connectivity**: Nodes must be on the same network segment (192.168.1.0/24)
- **DHCP Server**: Configured with PXE boot options pointing to Matchbox
- **DNS Resolution**: Ensure the following hostnames resolve:
  - `omni.home.usableapps.io` → 192.168.1.8
  - `matchbox.home.usableapps.io` → 192.168.1.8
  - `omni-siderolink.home.usableapps.io` → 192.168.1.8

### 2. Matchbox Assets

Verify Talos assets are downloaded and available:

```bash
# Check for kernel and initramfs
ls -la matchbox/data/assets/
ls -la matchbox/data/assets/talos/

# Expected files:
# - vmlinuz-amd64
# - initramfs-amd64.xz
# - Other Talos assets
```

If assets are missing, run:
```bash
./download-talos-assets.sh
```

### 3. Node Information

Your configured nodes:
| Node | Role | UUID | Serial | MAC Address |
|------|------|------|--------|-------------|
| curly | Control Plane | 03000200-0400-0500-0006-000700080009 | 0QVNF3GA302961 | (from hardware) |
| larry | Control Plane | (from node) | (from node) | (from hardware) |
| moe | Control Plane | (from node) | (from node) | (from hardware) |
| legion | Worker | (from node) | (from node) | (from hardware) |

## Network Configuration Requirements

### 1. DHCP Server Configuration

Your DHCP server (typically dnsmasq) must include PXE boot options:

```conf
# Example dnsmasq configuration
dhcp-range=192.168.1.100,192.168.1.200,12h
dhcp-option=option:router,192.168.1.1
dhcp-option=option:dns-server,192.168.1.1

# PXE Boot Configuration
dhcp-boot=tag:ipxe,http://matchbox.home.usableapps.io:8088/boot.ipxe
dhcp-match=set:ipxe,175 # iPXE sends a 175 option
dhcp-boot=tag:!ipxe,undionly.kpxe,matchbox.home.usableapps.io

# Enable TFTP if serving undionly.kpxe
enable-tftp
tftp-root=/var/lib/tftpboot
```

### 2. Firewall Rules

Ensure the following ports are open on the Matchbox/Omni host:

```bash
# Required ports
- 8088/tcp  # Matchbox HTTP
- 8081/tcp  # Matchbox RPC
- 8080/tcp  # Omni API
- 8090/tcp  # Siderolink API
- 50180/udp # Siderolink WireGuard
- 67/udp    # DHCP (if running on same host)
- 69/udp    # TFTP (if serving iPXE)
```

### 3. Network Verification

```bash
# Test connectivity from another machine on the network
curl -k https://matchbox.home.usableapps.io:8088/boot.ipxe
curl -k https://omni.home.usableapps.io/

# Verify DNS resolution
nslookup matchbox.home.usableapps.io
nslookup omni.home.usableapps.io
```

## BIOS/UEFI Settings

Configure each node's BIOS/UEFI for PXE boot:

### 1. Common Settings

1. **Boot Mode**: 
   - Legacy BIOS or UEFI (ensure consistency across nodes)
   - If using UEFI, disable Secure Boot

2. **Network Boot**:
   - Enable PXE Boot/Network Boot
   - Set network boot as first priority or use boot menu

3. **Wake-on-LAN** (optional but recommended):
   - Enable WoL for remote power management

### 2. BIOS-Specific Steps

**For AMI BIOS (common):**
1. Press DEL or F2 during boot
2. Navigate to Boot → Boot Option Priorities
3. Set Network/PXE as Boot Option #1
4. Save and Exit (F10)

**For UEFI Systems:**
1. Enter UEFI setup (DEL/F2/F12)
2. Disable Secure Boot under Security tab
3. Enable Network Stack under Advanced → Network
4. Set IPv4 PXE Support to Enabled
5. Configure Boot Order with IPv4 PXE first

## Step-by-Step Testing Procedure

### 1. Pre-Boot Verification

```bash
# 1. Verify Matchbox is running and healthy
docker compose -f docker-compose-qnap.yml ps matchbox

# 2. Check Matchbox logs for any errors
docker compose -f docker-compose-qnap.yml logs -f matchbox

# 3. Test Matchbox HTTP endpoint
curl -k https://matchbox.home.usableapps.io:8088/
# Should return: matchbox

# 4. Verify boot.ipxe is accessible
curl -k https://matchbox.home.usableapps.io:8088/boot.ipxe
# Should return iPXE script content
```

### 2. Initial PXE Boot Test

1. **Start with one node (e.g., curly)**:
   ```bash
   # Monitor Matchbox logs in one terminal
   docker compose -f docker-compose-qnap.yml logs -f matchbox
   
   # Monitor Omni logs in another terminal
   docker compose -f docker-compose-qnap.yml logs -f omni
   ```

2. **Power on the node** and watch for:
   - DHCP request
   - PXE boot initiation
   - iPXE chain loading
   - Kernel/initramfs download

3. **Expected boot sequence**:
   ```
   1. BIOS/UEFI POST
   2. "PXE Boot: Press Ctrl+B for iPXE menu" (or similar)
   3. DHCP request and response
   4. Download boot.ipxe from Matchbox
   5. iPXE executes and chains to Matchbox
   6. Download vmlinuz-amd64 and initramfs-amd64.xz
   7. Boot into Talos Linux
   ```

### 3. Boot Process Verification

Monitor the node's console for:

```
# Early boot messages
iPXE initializing devices...
DHCP (net0 aa:bb:cc:dd:ee:ff)... ok
http://matchbox.home.usableapps.io:8088/boot.ipxe... ok
http://matchbox.home.usableapps.io:8088/ipxe?uuid=...&mac=... ok

# Kernel loading
http://matchbox.home.usableapps.io:8088/assets/vmlinuz-amd64... ok
http://matchbox.home.usableapps.io:8088/assets/initramfs-amd64.xz... ok

# Talos boot
[    0.000000] Linux version 6.x.x-talos
[    1.234567] talos: starting init
```

## Verifying Matchbox Services

### 1. Check Asset Availability

```bash
# List all available assets
curl -k https://matchbox.home.usableapps.io:8088/assets/

# Verify specific assets
curl -k -I https://matchbox.home.usableapps.io:8088/assets/vmlinuz-amd64
curl -k -I https://matchbox.home.usableapps.io:8088/assets/initramfs-amd64.xz

# Check profile matching
curl -k "https://matchbox.home.usableapps.io:8088/ipxe?uuid=03000200-0400-0500-0006-000700080009"
```

### 2. Verify Group and Profile Configuration

```bash
# Inside the container
docker exec matchbox ls -la /var/lib/matchbox/groups/
docker exec matchbox ls -la /var/lib/matchbox/profiles/

# Check specific node group
docker exec matchbox cat /var/lib/matchbox/groups/controlplane-curly.json
```

### 3. Monitor Matchbox Metrics

```bash
# Check Matchbox request logs
docker compose -f docker-compose-qnap.yml logs matchbox | grep -E "GET|POST"

# Look for successful asset serves
docker compose -f docker-compose-qnap.yml logs matchbox | grep "200"
```

## Troubleshooting Common Issues

### 1. Node Not Attempting PXE Boot

**Symptoms**: Node boots to local disk or shows "No bootable device"

**Solutions**:
- Verify BIOS boot order has network boot first
- Check if PXE ROM is enabled in BIOS
- For UEFI: Ensure IPv4 network stack is enabled
- Try both Legacy and UEFI boot modes

### 2. DHCP Timeout

**Symptoms**: "DHCP... No response" or timeout messages

**Solutions**:
```bash
# Check DHCP server logs
sudo journalctl -u dnsmasq -f

# Verify DHCP configuration
sudo dnsmasq --test

# Test DHCP from another machine
sudo dhclient -v eth0
```

### 3. iPXE Download Failures

**Symptoms**: "Connection timed out" or "404 Not Found"

**Debug steps**:
```bash
# 1. Check Matchbox is accessible
curl -k https://matchbox.home.usableapps.io:8088/boot.ipxe

# 2. Verify nginx is properly proxying
curl -k -v https://matchbox.home.usableapps.io:8088/

# 3. Check for certificate issues
openssl s_client -connect matchbox.home.usableapps.io:8088

# 4. Test from node's network segment
# Use another machine on same network to test
```

### 4. Kernel Panic or Boot Failures

**Symptoms**: Kernel panic, unable to mount root, init failures

**Solutions**:
- Verify Talos version compatibility
- Check kernel arguments in profile:
  ```bash
  docker exec matchbox cat /var/lib/matchbox/profiles/talos-controlplane.json
  ```
- Ensure hardware compatibility (especially storage controllers)
- Try safe mode boot arguments:
  ```json
  "args": [
    "initrd=initramfs-amd64.xz",
    "console=tty0",
    "console=ttyS0,115200",
    "talos.platform=metal",
    "talos.config=...",
    "nomodeset"  // For graphics issues
  ]
  ```

### 5. Node Not Appearing in Omni

**Symptoms**: Node boots but doesn't register in Omni

**Debug steps**:
```bash
# 1. Check Siderolink connectivity
docker compose -f docker-compose-qnap.yml logs omni | grep -i siderolink

# 2. Verify node can reach Omni
# From node console if available:
curl -k https://omni-siderolink.home.usableapps.io

# 3. Check for certificate issues
docker compose -f docker-compose-qnap.yml logs omni | grep -i "certificate\|tls"

# 4. Verify WireGuard port is open
sudo netstat -ulnp | grep 50180
```

## Monitoring the Boot Process

### 1. Real-Time Log Monitoring

Create a monitoring script `monitor-pxe-boot.sh`:

```bash
#!/bin/bash
# Monitor PXE boot process

echo "=== Starting PXE Boot Monitor ==="
echo "Watching: Matchbox, Omni, and DHCP logs"
echo "Press Ctrl+C to stop"

# Terminal 1: Matchbox
gnome-terminal --tab --title="Matchbox" -- bash -c "docker compose -f docker-compose-qnap.yml logs -f matchbox"

# Terminal 2: Omni
gnome-terminal --tab --title="Omni" -- bash -c "docker compose -f docker-compose-qnap.yml logs -f omni"

# Terminal 3: DHCP (adjust for your DHCP server)
gnome-terminal --tab --title="DHCP" -- bash -c "sudo journalctl -u dnsmasq -f"

# Main terminal: Watch for HTTP requests
watch -n 1 'docker compose -f docker-compose-qnap.yml logs matchbox | grep "GET" | tail -20'
```

### 2. Network Traffic Monitoring

```bash
# Monitor DHCP traffic
sudo tcpdump -i any -n port 67 or port 68

# Monitor HTTP traffic to Matchbox
sudo tcpdump -i any -n port 8088

# Monitor all PXE-related traffic
sudo tcpdump -i any -n '(port 67 or port 68 or port 69 or port 8088)'
```

### 3. Boot Progress Indicators

Watch for these key milestones:

1. **DHCP Assignment** (0-5 seconds)
   ```
   dnsmasq-dhcp[1234]: DHCPDISCOVER(eth0) aa:bb:cc:dd:ee:ff
   dnsmasq-dhcp[1234]: DHCPOFFER(eth0) 192.168.1.150 aa:bb:cc:dd:ee:ff
   ```

2. **iPXE Download** (5-10 seconds)
   ```
   matchbox | 192.168.1.150 - - [timestamp] "GET /boot.ipxe HTTP/1.1" 200
   ```

3. **Profile Matching** (10-15 seconds)
   ```
   matchbox | 192.168.1.150 - - [timestamp] "GET /ipxe?uuid=...&mac=... HTTP/1.1" 200
   ```

4. **Kernel/Initramfs Download** (15-60 seconds)
   ```
   matchbox | 192.168.1.150 - - [timestamp] "GET /assets/vmlinuz-amd64 HTTP/1.1" 200
   matchbox | 192.168.1.150 - - [timestamp] "GET /assets/initramfs-amd64.xz HTTP/1.1" 200
   ```

5. **Talos Configuration** (60-90 seconds)
   ```
   matchbox | 192.168.1.150 - - [timestamp] "GET /assets/talos/config?uuid=...&mac=... HTTP/1.1" 200
   ```

## Verifying Node Registration in Omni

### 1. Check Omni UI

1. Access Omni web interface:
   ```
   https://omni.home.usableapps.io/
   ```

2. Navigate to **Machines** section

3. Look for new machines appearing with:
   - Status: "Connected" or "Running"
   - UUID matching your node configuration
   - Proper hostname (curly, larry, moe, or legion)

### 2. CLI Verification

Using `omnictl` (if configured):

```bash
# List all machines
omnictl get machines

# Get specific machine details
omnictl get machine curly -o yaml

# Watch for new machines
omnictl get machines -w
```

### 3. API Verification

```bash
# Check machine registration via API
curl -k -H "Authorization: Bearer $TOKEN" \
  https://omni.home.usableapps.io/api/v1/machines

# Get specific machine
curl -k -H "Authorization: Bearer $TOKEN" \
  https://omni.home.usableapps.io/api/v1/machines/curly
```

### 4. Expected Machine State Progression

1. **Initial Registration** (1-2 minutes after boot)
   - State: "Connecting"
   - Siderolink: "Establishing"

2. **Connected** (2-3 minutes)
   - State: "Connected"
   - Siderolink: "Up"
   - Maintenance mode: true

3. **Ready** (3-5 minutes)
   - State: "Running"
   - Maintenance mode: false
   - Ready for cluster creation

## Node-Specific Testing

### Testing Individual Nodes

#### 1. Control Plane Node: Curly

```bash
# Pre-boot verification
cat matchbox/data/groups/controlplane-curly.json

# Expected identifiers:
# UUID: 03000200-0400-0500-0006-000700080009
# Serial: 0QVNF3GA302961
# Role: controlplane

# Boot and monitor
echo "Booting Curly - Control Plane Node 1"
# Power on node and monitor logs

# Verify in Omni
curl -k https://omni.home.usableapps.io/api/v1/machines | jq '.[] | select(.hostname=="curly")'
```

#### 2. Control Plane Node: Larry

```bash
# Similar process for Larry
echo "Booting Larry - Control Plane Node 2"
# Check group configuration and boot
```

#### 3. Control Plane Node: Moe

```bash
# Similar process for Moe
echo "Booting Moe - Control Plane Node 3"
# Check group configuration and boot
```

#### 4. Worker Node: Legion

```bash
# Worker node has different profile
cat matchbox/data/groups/worker-legion.json

# Boot and verify worker-specific configuration
echo "Booting Legion - Worker Node"
```

### Batch Testing Script

Create `test-all-nodes.sh`:

```bash
#!/bin/bash
# Test all nodes sequentially

NODES=("curly" "larry" "moe" "legion")
OMNI_URL="https://omni.home.usableapps.io"

echo "=== PXE Boot Test for All Nodes ==="

for node in "${NODES[@]}"; do
    echo ""
    echo "Testing node: $node"
    echo "1. Power on $node now"
    echo "2. Waiting for PXE boot..."
    
    # Wait for user confirmation
    read -p "Press Enter when $node has started booting..."
    
    # Monitor for 2 minutes
    timeout 120 docker compose -f docker-compose-qnap.yml logs -f matchbox | grep -i "$node"
    
    # Check if node appears in Omni
    sleep 30
    if curl -sk "$OMNI_URL/api/v1/machines" | grep -q "$node"; then
        echo "✓ $node successfully registered in Omni"
    else
        echo "✗ $node not found in Omni - check logs"
    fi
done

echo ""
echo "=== Test Complete ==="
echo "Check Omni UI for all nodes: $OMNI_URL"
```

### Performance Benchmarks

Expected timings for successful PXE boot:

| Phase | Duration | Description |
|-------|----------|-------------|
| DHCP | 1-5s | IP assignment |
| iPXE Load | 2-5s | Initial bootloader |
| Profile Match | 1-2s | Matchbox selection |
| Kernel Download | 10-30s | ~50MB kernel |
| Initramfs Download | 20-60s | ~100MB initramfs |
| Talos Boot | 30-60s | OS initialization |
| Omni Registration | 30-90s | Siderolink connection |
| **Total** | **2-5 minutes** | To "Running" state |

## Advanced Debugging

### 1. Enable Verbose Logging

```yaml
# In docker-compose-qnap.yml, add to Matchbox:
environment:
  - MATCHBOX_LOG_LEVEL=debug
  - MATCHBOX_LOG_FORMAT=json
```

### 2. Packet Capture for Deep Analysis

```bash
# Capture all PXE boot traffic
sudo tcpdump -i any -w pxe-boot-$(date +%Y%m%d-%H%M%S).pcap \
  '(port 67 or port 68 or port 69 or port 8088 or port 8080)'

# Analyze with Wireshark
wireshark pxe-boot-*.pcap
```

### 3. Console Access

For nodes with serial console:

```bash
# Connect via serial (adjust device as needed)
screen /dev/ttyUSB0 115200

# Or via IPMI if available
ipmitool -I lanplus -H <node-ipmi-ip> -U admin -P password sol activate
```

## Success Criteria

A successful PXE boot test includes:

1. ✓ Node obtains IP via DHCP
2. ✓ iPXE downloads and executes
3. ✓ Correct profile matched in Matchbox
4. ✓ Kernel and initramfs download completely
5. ✓ Talos boots without errors
6. ✓ Node establishes Siderolink connection
7. ✓ Node appears in Omni UI as "Running"
8. ✓ Node ready for cluster operations

## Quick Reference Commands

```bash
# Check all services
docker compose -f docker-compose-qnap.yml ps

# Monitor all relevant logs
docker compose -f docker-compose-qnap.yml logs -f matchbox omni

# Test Matchbox endpoints
curl -k https://matchbox.home.usableapps.io:8088/
curl -k https://matchbox.home.usableapps.io:8088/boot.ipxe
curl -k https://matchbox.home.usableapps.io:8088/assets/

# Verify node in Omni (replace with actual machine ID)
curl -k https://omni.home.usableapps.io/api/v1/machines/<machine-id>

# Force re-download of Talos assets
./download-talos-assets.sh --force

# Restart services if needed
docker compose -f docker-compose-qnap.yml restart matchbox
docker compose -f docker-compose-qnap.yml restart omni
```

## Next Steps

After successful PXE boot testing:

1. **Create Talos Cluster**: Use Omni UI to create a cluster with the booted nodes
2. **Configure Storage**: Set up storage classes and persistent volumes
3. **Install Workloads**: Deploy applications to your new cluster
4. **Set Up Monitoring**: Configure observability for the cluster

---

For additional support, check the logs thoroughly and ensure all network paths are open between nodes, Matchbox, and Omni services.