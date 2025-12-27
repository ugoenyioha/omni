# DDNS Updater for Omni-Docker

This service provides automatic DNS updates using TSIG authentication for secure dynamic DNS updates.

## Features

- TSIG key-based authentication for secure DNS updates
- Support for multiple DNS records
- Automatic updates when IP changes
- Configurable update interval
- Support for static IPs or dynamic container IPs

## Configuration

### TSIG Key

Place your TSIG key in a file named `tsig.key` in the omni-docker root directory.

Example TSIG key format:
```
key "client2" {
    algorithm hmac-sha512;
    secret "your-base64-encoded-secret-here";
};
```

### Environment Variables

- `DNS_SERVER`: DNS server to update (default: 192.168.1.29)
- `DNS_ZONE`: DNS zone to update (default: home.usableapps.io)
- `DNS_TTL`: TTL for DNS records in seconds (default: 300)
- `UPDATE_INTERVAL`: How often to check for updates in seconds (default: 60)
- `DNS_RECORDS`: Comma-separated list of records to update

### DNS Records Format

The `DNS_RECORDS` variable uses the format: `hostname:ip_source`

Where `ip_source` can be:
- A specific IP address (e.g., `192.168.1.8`)
- `container` - Use the container's IP address
- `macvlan` - Use the macvlan network IP address

Example:
```
DNS_RECORDS=omni:192.168.1.8,omni-siderolink:192.168.1.8,omni-k8s:192.168.1.8,matchbox:192.168.1.8
```

## Usage

The DDNS updater is included in the docker-compose files and will start automatically with:

```bash
docker compose up -d
```

To view logs:
```bash
docker logs ddns-updater -f
```

## DNS Server Configuration

Ensure your DNS server is configured to accept dynamic updates with TSIG keys:

### BIND9 Example

```
zone "home.usableapps.io" {
    type master;
    file "/var/cache/bind/db.home.usableapps.io";
    allow-update { key "omni-ddns"; };
};
```

### PowerDNS Example

```
gsqlite3-dnssec=yes
allow-dnsupdate-from=0.0.0.0/0,::/0
dnsupdate=yes
```

## Troubleshooting

1. **TSIG key not found**: Ensure `tsig.key` exists and is readable
2. **Authentication failed**: Verify TSIG key matches server configuration
3. **Updates not working**: Check DNS server logs and ensure zone allows updates
4. **Network issues**: Verify container can reach DNS server

## Security Notes

- Keep TSIG keys secure and never commit them to version control
- Use appropriate file permissions (600) for tsig.key
- Consider using separate TSIG keys for different services
- Regularly rotate TSIG keys