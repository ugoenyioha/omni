# Vault Integration for SSL Certificates

This deployment uses HashiCorp Vault with AppRole authentication to automatically manage SSL certificates.

## Overview

The `vault-cert-manager` service:
- Uses AppRole authentication for automated access
- Fetches SSL certificates from Vault PKI backend
- Automatically renews both tokens and certificates
- Provides certificates to Nginx for all HTTPS services

## Configuration

### Environment Variables

- `VAULT_ADDR`: Vault server address (default: https://vault.home.usableapps.io)
- `VAULT_NAMESPACE`: Vault namespace (default: admin)
- `VAULT_PKI_PATH`: PKI signing path (default: pki_int/sign/qnap-cert-manager)

### Certificate Details

- **Common Name**: omni.home.usableapps.io
- **Subject Alternative Names**:
  - omni.home.usableapps.io
  - omni-siderolink.home.usableapps.io
  - omni-k8s.home.usableapps.io
  - matchbox.home.usableapps.io
- **Allowed Domains**: *.home.usableapps.io, *.onprem.usableapps.io
- **Key Types**: RSA, EC, Ed25519
- **TTL**: 30 days
- **Renewal**: 7 days before expiry

## Setup

### 1. Configure Vault AppRole

```bash
./setup-vault-approle.sh
```

This will:
- Enable AppRole auth method
- Create cert-manager policy
- Create AppRole with renewable tokens
- Generate role-id and secret-id files
- Test authentication and certificate issuance

### 2. Deploy Services

```bash
docker-compose up -d
```

## How It Works

1. **AppRole Authentication**: On startup, authenticates using role-id and secret-id
2. **Token Management**: Automatically renews Vault tokens at 50% of lease duration
3. **Certificate Monitoring**: Checks certificate expiry every hour
4. **Automatic Renewal**: Renews certificates 7 days before expiry
5. **Nginx Reload**: Automatically reloads Nginx after certificate update

## Security

### AppRole Credentials
- **role-id**: Less sensitive, like a username
- **secret-id**: Sensitive, like a password - protect accordingly

### Regenerating Credentials
If secret-id is compromised:
```bash
vault write -field=secret_id -f auth/approle/role/cert-manager/secret-id > secret-id
chmod 600 secret-id
docker-compose restart vault-cert-manager
```

## Monitoring

Check vault-cert-manager logs:
```bash
docker logs vault-cert-manager -f
```

Expected log entries:
- "Authenticating with Vault using AppRole..."
- "Successfully authenticated with Vault"
- "Certificate is still valid" (hourly)
- "Token renewed successfully" (every ~30 minutes)

## Troubleshooting

### Authentication Failures
```bash
# Verify AppRole is enabled
vault auth list

# Check role exists
vault read auth/approle/role/cert-manager

# Test authentication
vault write auth/approle/login role_id=@role-id secret_id=@secret-id
```

### Certificate Not Found
```bash
# Check PKI role
vault read pki_int/roles/qnap-cert-manager

# Verify policy permissions
vault policy read cert-manager-policy

# Test certificate issuance
vault write pki_int/sign/qnap-cert-manager \
  common_name=test.home.usableapps.io \
  ttl=5m
```

### Token Renewal Issues
```bash
# Check token status
docker exec vault-cert-manager vault token lookup

# Review Vault audit logs for renewal attempts
# Verify AppRole token_period is set correctly
```

## Manual Operations

### Fetch Certificate Manually
```bash
docker exec vault-cert-manager /vault-cert-manager.sh fetch
```

### Force Token Renewal
```bash
docker exec vault-cert-manager vault token renew
```

## Migration from Token-Based Auth

If upgrading from the old token-based authentication:

1. Run the AppRole setup script
2. Remove old token file: `rm -f vault-token`
3. Update docker-compose files (already done)
4. Restart the certificate manager:
   ```bash
   docker-compose restart vault-cert-manager
   ```

## Vault Policy Reference

The cert-manager-policy should contain:
```hcl
# Allow tokens to look up their own properties
path "auth/token/lookup-self" {
  capabilities = ["read"]
}

# Allow tokens to renew themselves
path "auth/token/renew-self" {
  capabilities = ["update"]
}

# Allow cert-manager to issue certificates
path "pki_int/sign/qnap-cert-manager" {
  capabilities = ["create", "update"]
}

# Allow cert-manager to read certificate info (optional)
path "pki_int/cert/*" {
  capabilities = ["read"]
}
```