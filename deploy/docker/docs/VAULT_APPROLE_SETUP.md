# Vault AppRole Setup for Certificate Manager

This guide sets up AppRole authentication for automated certificate management.

## Prerequisites

- Vault CLI installed and configured
- Admin access to Vault
- Vault address and namespace configured

## Step 1: Enable AppRole Auth Method

```bash
# Set your Vault environment
export VAULT_ADDR="https://vault.home.usableapps.io"
export VAULT_NAMESPACE="admin"

# Login as admin
vault login

# Enable AppRole if not already enabled
vault auth enable approle
```

## Step 2: Create Certificate Manager Policy

Create a policy that allows the cert-manager to issue certificates:

```bash
# Create the policy
vault policy write cert-manager-policy - <<EOF
# Allow tokens to look up their own properties
path "auth/token/lookup-self" {
  capabilities = ["read"]
}

# Allow tokens to renew themselves
path "auth/token/renew-self" {
  capabilities = ["update"]
}

# Allow tokens to revoke themselves
path "auth/token/revoke-self" {
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
EOF
```

## Step 3: Create AppRole for Certificate Manager

```bash
# Create the AppRole
vault write auth/approle/role/cert-manager \
    token_policies="cert-manager-policy" \
    token_ttl=1h \
    token_max_ttl=24h \
    token_explicit_max_ttl=0 \
    secret_id_ttl=0 \
    token_num_uses=0 \
    secret_id_num_uses=0 \
    token_period=1h
```

Parameters explained:
- `token_ttl=1h`: Tokens valid for 1 hour
- `token_period=1h`: Tokens can renew indefinitely every hour
- `secret_id_ttl=0`: Secret ID never expires
- `secret_id_num_uses=0`: Secret ID can be used unlimited times

## Step 4: Retrieve AppRole Credentials

```bash
# Get the Role ID (like a username)
vault read -field=role_id auth/approle/role/cert-manager/role-id > role-id

# Generate a Secret ID (like a password)
vault write -field=secret_id -f auth/approle/role/cert-manager/secret-id > secret-id

# Secure the files
chmod 600 role-id secret-id
```

## Step 5: Test AppRole Authentication

```bash
# Test login with AppRole
vault write auth/approle/login \
    role_id=$(cat role-id) \
    secret_id=$(cat secret-id)

# You should see a token in the response
```

## Step 6: Update Docker Compose Configuration

Add the AppRole credentials to your docker-compose files:

```yaml
vault-cert-manager:
  environment:
    - VAULT_ADDR=${VAULT_ADDR:-https://vault.home.usableapps.io}
    - VAULT_NAMESPACE=${VAULT_NAMESPACE:-admin}
  volumes:
    - ./role-id:/run/secrets/role-id:ro
    - ./secret-id:/run/secrets/secret-id:ro
    - ssl-certs:/etc/nginx/ssl
```

## Step 7: Verify PKI Role Configuration

Ensure your PKI role allows the required domains:

```bash
# Check the role configuration
vault read pki_int/roles/qnap-cert-manager

# It should allow:
# - *.home.usableapps.io
# - *.onprem.usableapps.io
# - Key types: rsa, ec, ed25519
```

## Security Considerations

1. **Protect the Secret ID**: 
   - The secret-id file is sensitive
   - Consider using Vault's response wrapping for initial delivery
   - Can regenerate if compromised

2. **Role ID is Less Sensitive**:
   - Can be embedded in the container image
   - Still protect it from public exposure

3. **Token Renewal**:
   - The cert-manager will automatically renew its token
   - Monitor Vault audit logs for renewal failures

## Alternative: Using Response Wrapping

For enhanced security, wrap the Secret ID:

```bash
# Create wrapped Secret ID (valid for 30 minutes)
vault write -wrap-ttl=30m -f auth/approle/role/cert-manager/secret-id

# Save the wrapping token
# The cert-manager can unwrap this once to get the actual Secret ID
```

## Monitoring

Check AppRole usage:
```bash
# View audit logs
vault audit list

# Check token accessor
vault token lookup -accessor <accessor_from_login>
```

## Next Steps

1. Update the vault-cert-manager script to use AppRole
2. Remove the old token-based authentication
3. Test certificate issuance with the new auth method