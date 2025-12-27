#!/bin/sh
# wait-for-certs.sh - Wait for SSL certificates to be created by vault-cert-manager

set -e

CERT_FILE="/etc/nginx/ssl/server.crt"
KEY_FILE="/etc/nginx/ssl/server.key"
TIMEOUT=60
INTERVAL=2

echo "Waiting for SSL certificates to be created..."
echo "Looking for: $CERT_FILE and $KEY_FILE"

elapsed=0
while [ $elapsed -lt $TIMEOUT ]; do
    if [ -f "$CERT_FILE" ] && [ -f "$KEY_FILE" ]; then
        echo "Certificates found! Starting nginx..."
        exec nginx -g 'daemon off;'
    fi
    
    echo "Certificates not found yet. Waiting... ($elapsed/$TIMEOUT seconds)"
    sleep $INTERVAL
    elapsed=$((elapsed + INTERVAL))
done

echo "ERROR: Timeout waiting for certificates after $TIMEOUT seconds"
echo "Please check vault-cert-manager logs"
exit 1