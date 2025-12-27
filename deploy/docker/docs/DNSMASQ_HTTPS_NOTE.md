# Important: dnsmasq and HTTPS for PXE Boot

## The Challenge

Traditional PXE boot (using TFTP) cannot directly use HTTPS URLs. However, we can work around this using iPXE chain loading.

## Solution Options

### Option 1: HTTP Redirect (Recommended)
Add an HTTP listener in nginx that redirects to HTTPS for web browsers but serves iPXE directly:

```nginx
# Add to nginx config - HTTP listener for iPXE only
server {
    listen 192.168.1.8:80;  # For both QNAP and Arch (using macvlan)
    server_name matchbox.home.usableapps.io;

    # Serve iPXE boot script directly over HTTP
    location = /boot.ipxe {
        proxy_pass http://matchbox:8080;
        proxy_set_header Host $host;
    }

    # Redirect everything else to HTTPS
    location / {
        return 301 https://$server_name$request_uri;
    }
}
```

Then in dnsmasq:
```
dhcp-boot=tag:ipxe,http://matchbox.home.usableapps.io/boot.ipxe
```

### Option 2: iPXE with HTTPS Support
Use iPXE builds that include HTTPS support:

1. Download iPXE with HTTPS: https://boot.ipxe.org/ipxe.efi
2. Configure dnsmasq to chainload iPXE first
3. iPXE can then fetch from HTTPS

### Option 3: Embedded Certificate
Build custom iPXE with embedded certificates for your domain.

## Current Implementation

For now, the nginx configurations support HTTPS for Matchbox. To enable PXE boot, you'll need to either:

1. Add the HTTP listener shown above
2. Use iPXE with HTTPS support
3. Temporarily allow HTTP for boot.ipxe endpoint only

## Security Note

The initial PXE boot happens over HTTP/TFTP (unencrypted), but once the kernel is loaded, all subsequent communication happens over secure SideroLink (WireGuard).