# Unified Configuration Summary

After consolidation, both Arch Linux and QNAP deployments are now virtually identical.

## What's Unified

1. **Network Architecture**
   - Both use macvlan with IP 192.168.1.8
   - Both use standard ports (443/80)
   - No port conflicts with host services

2. **Volume Mounts**
   - All use bind mounts for direct file access:
     - `./data` - Omni data
     - `./matchbox/data` - Matchbox assets (Talos kernels)
     - `./matchbox/etc` - Matchbox certificates
     - `./omni.asc` - GPG encryption key
     - `./vault-token` - Vault authentication

3. **Service Configuration**
   - Identical nginx configuration (`nginx/omni.conf`)
   - Same SSL certificate paths
   - Same service dependencies
   - Same Watchtower update strategy

4. **Build Process**
   - Both build vault-cert-manager from Dockerfile
   - Same container versions
   - Same environment variables

## Minimal Differences

The only differences between `docker-compose-arch.yml` and `docker-compose-qnap.yml`:

1. **Comment header** - Identifies which platform
2. **Instance name** - `--name=Arch Linux Omni` vs `--name=QNAP Omni`
3. **Network reference** - Comments mention respective network creation scripts

## Benefits

- **Simplified maintenance**: Nearly identical files
- **Easy file access**: All data directories use bind mounts
- **Consistent behavior**: Same configuration on both platforms
- **Reduced complexity**: No need to handle different volume types

## Directory Structure

The `setup.sh` script creates all required directories:
- `data/` - Omni etcd data
- `_out/` - Omni output files
- `matchbox/data/profiles/` - Matchbox profiles
- `matchbox/data/groups/` - Matchbox groups
- `matchbox/data/assets/talos/` - Talos kernels and initramfs
- `matchbox/etc/` - Matchbox certificates (already included)

## File Access

You can now directly access all important files:

```bash
# Add Talos kernels
cp vmlinuz initramfs.xz ./matchbox/data/assets/talos/

# Update Matchbox profiles
vi ./matchbox/data/profiles/talos.json

# Check Omni data
ls ./data/

# Update certificates
cp *.crt *.key ./matchbox/etc/
```

This works identically on both Arch Linux and QNAP.