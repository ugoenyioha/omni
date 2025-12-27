# QNAP Deployment Checklist

## Pre-Deployment
- [ ] Verify IP 192.168.1.8 is available: `ping 192.168.1.8`
- [ ] Ensure you have SSH access to QNAP
- [ ] Run `./setup-vault-auth.sh` to get Vault token
- [ ] Verify `omni.asc` GPG key exists
- [ ] Check DNS entries point to 192.168.1.8
- [ ] Verify Docker is installed on QNAP

## Deployment Steps

### 1. Run the automated deployment:
```bash
cd /Users/uenyioha/Documents/code/shirley/sidero/omni-docker
./deploy-to-qnap.sh
```

This script will:
- Build the vault-cert-manager image
- Create deployment package
- Upload to QNAP
- Create macvlan network with IP 192.168.1.8
- Deploy all services (including Watchtower)
- Download Talos assets

### 2. Verify deployment:
```bash
ssh admin@qnap
cd /share/Container/omni-docker
docker-compose -f docker-compose-qnap.yml ps
```

All containers should be running.

### 3. Check network:
```bash
docker network inspect omni-macvlan
```

Should show the macvlan network with 192.168.1.8 assigned.

### 4. Test access:
- https://omni.home.usableapps.io (port 443)
- https://matchbox.home.usableapps.io (port 443)
- http://matchbox.home.usableapps.io/boot.ipxe (port 80 - for PXE boot only)

## Post-Deployment

### 1. Get Omni kernel parameters:
- Access https://omni.home.usableapps.io
- Login with SAML
- Click "Copy Kernel Parameters"

### 2. Update Matchbox profile:
```bash
./update-matchbox-profile.sh
# Paste the kernel parameters when prompted
```

### 3. Configure dnsmasq (on another system):
```
dhcp-match=set:ipxe,option:user-class,iPXE
dhcp-boot=tag:ipxe,http://matchbox.home.usableapps.io/boot.ipxe
```

## Troubleshooting

### Check logs:
```bash
ssh admin@qnap
cd /share/Container/omni-docker
docker-compose -f docker-compose-qnap.yml logs -f
```

### Restart services:
```bash
docker-compose -f docker-compose-qnap.yml restart
```

### Network issues:
- Remember: QNAP host cannot directly access 192.168.1.8
- Test from another device on the network
- Check firewall rules on QNAP

### Certificate issues:
```bash
docker logs vault-cert-manager
```

### Check Watchtower status:
```bash
docker logs watchtower
```

### Manual container updates:
```bash
./update-containers.sh --check  # Check for updates
./update-containers.sh nginx    # Update specific container
```

## Success Criteria
- [ ] All containers running (omni, nginx, matchbox, vault-cert-manager, watchtower)
- [ ] Can access Omni UI on HTTPS port 443
- [ ] Can login with SAML authentication
- [ ] Matchbox web UI accessible on HTTPS port 443
- [ ] PXE boot endpoint working on HTTP port 80
- [ ] SSL certificates loaded from Vault
- [ ] Kernel parameters obtained from Omni
- [ ] Watchtower monitoring for updates
- [ ] Ready for PXE boot testing

## Container Update Policy
- **Auto-update**: nginx, watchtower
- **Manual update**: omni, matchbox, vault-cert-manager
- Check updates daily at 3 AM via Watchtower