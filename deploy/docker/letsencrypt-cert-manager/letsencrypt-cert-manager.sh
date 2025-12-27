#!/bin/bash
set -e

# Configuration
CERT_DIR="${CERT_DIR:-/etc/nginx/ssl}"
CERT_COMMON_NAME="${CERT_COMMON_NAME:-*.home.usableapps.io}"
CERT_ALT_NAMES="${CERT_ALT_NAMES:-*.home.usableapps.io,*.usableapps.io,usableapps.io}"
LETSENCRYPT_EMAIL="${LETSENCRYPT_EMAIL:-admin@home.usableapps.io}"
LETSENCRYPT_STAGING="${LETSENCRYPT_STAGING:-false}"
RENEW_BEFORE_DAYS="${RENEW_BEFORE_DAYS:-30}"

# Cloudflare credentials file path
CLOUDFLARE_CREDS="/etc/letsencrypt/cloudflare.ini"

# Create Cloudflare credentials file
create_cloudflare_creds() {
    if [ -z "$CLOUDFLARE_API_TOKEN" ] && [ -z "$CLOUDFLARE_EMAIL" ]; then
        echo "ERROR: Either CLOUDFLARE_API_TOKEN or CLOUDFLARE_EMAIL and CLOUDFLARE_API_KEY must be set"
        exit 1
    fi
    
    # Create credentials file with restrictive permissions
    touch "$CLOUDFLARE_CREDS"
    chmod 600 "$CLOUDFLARE_CREDS"
    
    if [ -n "$CLOUDFLARE_API_TOKEN" ]; then
        # Use API Token (recommended)
        cat > "$CLOUDFLARE_CREDS" <<EOF
dns_cloudflare_api_token = ${CLOUDFLARE_API_TOKEN}
EOF
    else
        # Use Global API Key (legacy)
        cat > "$CLOUDFLARE_CREDS" <<EOF
dns_cloudflare_email = ${CLOUDFLARE_EMAIL}
dns_cloudflare_api_key = ${CLOUDFLARE_API_KEY}
EOF
    fi
}

# Convert comma-separated domains to certbot format
prepare_domains() {
    local domains=""
    IFS=',' read -ra DOMAIN_ARRAY <<< "$CERT_ALT_NAMES"
    for domain in "${DOMAIN_ARRAY[@]}"; do
        domains="$domains -d $domain"
    done
    echo "$domains"
}

# Check if certificate needs renewal
check_certificate() {
    if [ ! -f "$CERT_DIR/server.crt" ]; then
        echo "Certificate not found, requesting new certificate..."
        return 1
    fi
    
    # Check certificate expiry
    local expiry_date=$(openssl x509 -in "$CERT_DIR/server.crt" -noout -enddate | cut -d= -f2)
    local expiry_epoch=$(date -d "$expiry_date" +%s)
    local current_epoch=$(date +%s)
    local days_until_expiry=$(( ($expiry_epoch - $current_epoch) / 86400 ))
    
    echo "Certificate expires in $days_until_expiry days"
    
    if [ $days_until_expiry -lt $RENEW_BEFORE_DAYS ]; then
        echo "Certificate needs renewal (expires in less than $RENEW_BEFORE_DAYS days)"
        return 1
    fi
    
    return 0
}

# Request or renew certificate
request_certificate() {
    local domains=$(prepare_domains)
    local staging_flag=""
    
    if [ "$LETSENCRYPT_STAGING" = "true" ]; then
        staging_flag="--staging"
        echo "Using Let's Encrypt staging environment"
    fi
    
    echo "Requesting certificate for domains: $CERT_ALT_NAMES"
    
    certbot certonly \
        --non-interactive \
        --agree-tos \
        --email "$LETSENCRYPT_EMAIL" \
        --dns-cloudflare \
        --dns-cloudflare-credentials "$CLOUDFLARE_CREDS" \
        --dns-cloudflare-propagation-seconds 60 \
        $staging_flag \
        $domains \
        --cert-name "omni-cert"
    
    # Copy certificates to nginx directory
    cp /etc/letsencrypt/live/omni-cert/fullchain.pem "$CERT_DIR/server.crt"
    cp /etc/letsencrypt/live/omni-cert/privkey.pem "$CERT_DIR/server.key"
    
    # Set appropriate permissions
    chmod 644 "$CERT_DIR/server.crt"
    chmod 600 "$CERT_DIR/server.key"
    
    echo "Certificate successfully obtained and copied to $CERT_DIR"
}

# Main loop
main() {
    echo "Starting Let's Encrypt certificate manager..."
    echo "Common Name: $CERT_COMMON_NAME"
    echo "Alt Names: $CERT_ALT_NAMES"
    echo "Email: $LETSENCRYPT_EMAIL"
    
    # Create Cloudflare credentials
    create_cloudflare_creds
    
    while true; do
        if ! check_certificate; then
            request_certificate
        fi
        
        # Sleep for 12 hours before next check
        echo "Sleeping for 12 hours before next check..."
        sleep 43200
    done
}

# Handle shutdown gracefully
trap 'echo "Shutting down..."; exit 0' SIGTERM SIGINT

main