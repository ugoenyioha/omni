# Let's Encrypt Certificate Manager

This service automatically obtains and renews SSL certificates from Let's Encrypt using the Cloudflare DNS challenge.

## Features

- Automatic certificate request and renewal
- Wildcard certificate support (*.usableapps.io)
- Cloudflare DNS challenge (works behind firewalls)
- Support for multiple domains (SAN certificates)
- Configurable renewal threshold
- Uses certbot with cloudflare plugin

## Configuration

### Required Environment Variables

You must provide Cloudflare API credentials using ONE of these methods:

#### Method 1: API Token (Recommended)
- `CLOUDFLARE_API_TOKEN`: A scoped API token with DNS edit permissions

#### Method 2: Global API Key (Legacy)
- `CLOUDFLARE_EMAIL`: Your Cloudflare account email
- `CLOUDFLARE_API_KEY`: Your Cloudflare global API key

### Optional Environment Variables

- `CERT_DIR`: Directory to store certificates (default: `/etc/nginx/ssl`)
- `CERT_COMMON_NAME`: Primary domain name (default: `*.usableapps.io`)
- `CERT_ALT_NAMES`: Comma-separated list of domains (default: `*.usableapps.io,usableapps.io`)
- `LETSENCRYPT_EMAIL`: Email for Let's Encrypt notifications (default: `admin@home.usableapps.io`)
- `LETSENCRYPT_STAGING`: Use staging environment for testing (default: `false`)
- `RENEW_BEFORE_DAYS`: Days before expiry to renew (default: `30`)

## Creating a Cloudflare API Token

1. Log in to Cloudflare dashboard
2. Go to My Profile → API Tokens
3. Click "Create Token"
4. Use the "Edit zone DNS" template or create custom token with:
   - Permissions: Zone → DNS → Edit
   - Zone Resources: Include → Specific zone → your domain
5. Copy the token and set it as `CLOUDFLARE_API_TOKEN`

## Certificate Files

The service creates:
- `/etc/nginx/ssl/server.crt`: The certificate chain
- `/etc/nginx/ssl/server.key`: The private key

## Testing

To test with Let's Encrypt staging environment (to avoid rate limits):
```yaml
environment:
  - LETSENCRYPT_STAGING=true
```

## Rate Limits

Let's Encrypt has rate limits:
- 50 certificates per domain per week
- 5 duplicate certificates per week
- 300 new orders per account per 3 hours

Use the staging environment for testing to avoid hitting these limits.