#!/bin/bash
set -e

echo "Setting up Sidero Omni Docker deployment..."

# Check for required prerequisite files
echo "Checking for prerequisite files..."

# Check for role-id file
if [ ! -f "role-id" ]; then
    echo ""
    echo "ERROR: Missing required file: role-id"
    echo ""
    echo "The 'role-id' file is required for Vault AppRole authentication."
    echo ""
    echo "To obtain this file:"
    echo "  1. Contact your Vault administrator to get your AppRole credentials"
    echo "  2. Create a file named 'role-id' in the current directory"
    echo "  3. Add only the role ID value to the file (no extra whitespace or newlines)"
    echo ""
    echo "Example:"
    echo "  echo 'your-role-id-here' > role-id"
    echo ""
    exit 1
fi

# Check for secret-id file
if [ ! -f "secret-id" ]; then
    echo ""
    echo "ERROR: Missing required file: secret-id"
    echo ""
    echo "The 'secret-id' file is required for Vault AppRole authentication."
    echo ""
    echo "To obtain this file:"
    echo "  1. Contact your Vault administrator to get your AppRole credentials"
    echo "  2. Create a file named 'secret-id' in the current directory"
    echo "  3. Add only the secret ID value to the file (no extra whitespace or newlines)"
    echo ""
    echo "Example:"
    echo "  echo 'your-secret-id-here' > secret-id"
    echo ""
    exit 1
fi

echo "Prerequisite files found ✓"

# Create required directories for bind mounts
echo "Creating required directories..."
mkdir -p data
mkdir -p _out
mkdir -p matchbox/data/profiles
mkdir -p matchbox/data/groups
mkdir -p matchbox/data/assets/talos
mkdir -p matchbox/etc
mkdir -p nginx

# Check if GPG key exists
if [ ! -f "omni.asc" ]; then
    echo "Generating GPG key for Omni etcd encryption..."
    
    # Generate primary key for certification only
    gpg --quick-generate-key "Omni (Used for etcd data encryption) admin@home.usableapps.io" rsa4096 cert never
    
    # Get the fingerprint of the key we just created
    FINGERPRINT=$(gpg --list-secret-keys --with-fingerprint --with-colons | grep "Omni (Used for etcd data encryption)" -B 2 | grep ^fpr | cut -d: -f10)
    
    echo "Adding encryption subkey..."
    # Add encryption subkey
    gpg --quick-add-key "$FINGERPRINT" rsa4096 encr never
    
    echo "Exporting GPG key..."
    # Export the secret key
    gpg --export-secret-key --armor "admin@home.usableapps.io" > omni.asc
    echo "GPG key with encryption capability exported to omni.asc"
fi

# Generate Matchbox TLS certificates
echo "Checking Matchbox TLS certificates..."
if [ ! -f "matchbox/etc/ca.crt" ] || [ ! -f "matchbox/etc/server.crt" ] || [ ! -f "matchbox/etc/server.key" ]; then
    echo "Generating Matchbox TLS certificates..."
    
    # Create temporary directory for certificate generation
    CERT_DIR="matchbox/etc"
    mkdir -p "$CERT_DIR"
    
    # Generate CA private key
    echo "Generating Certificate Authority..."
    openssl genrsa -out "$CERT_DIR/ca.key" 4096
    
    # Generate CA certificate (valid for 10 years)
    openssl req -new -x509 -days 3650 -key "$CERT_DIR/ca.key" -out "$CERT_DIR/ca.crt" \
        -subj "/C=US/ST=State/L=City/O=Matchbox/CN=Matchbox CA"
    
    # Generate server private key
    echo "Generating server certificate..."
    openssl genrsa -out "$CERT_DIR/server.key" 4096
    
    # Create certificate configuration file with SANs
    cat > "$CERT_DIR/server.conf" <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = State
L = City
O = Matchbox
CN = matchbox

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
DNS.2 = matchbox
IP.1 = 127.0.0.1
EOF
    
    # Generate server certificate request
    openssl req -new -key "$CERT_DIR/server.key" -out "$CERT_DIR/server.csr" \
        -config "$CERT_DIR/server.conf"
    
    # Sign server certificate with CA (valid for 1 year)
    openssl x509 -req -in "$CERT_DIR/server.csr" -CA "$CERT_DIR/ca.crt" -CAkey "$CERT_DIR/ca.key" \
        -CAcreateserial -out "$CERT_DIR/server.crt" -days 365 \
        -extensions v3_req -extfile "$CERT_DIR/server.conf"
    
    # Clean up temporary files
    rm -f "$CERT_DIR/server.csr" "$CERT_DIR/server.conf" "$CERT_DIR/ca.srl"
    
    # Set appropriate permissions
    chmod 600 "$CERT_DIR/ca.key" "$CERT_DIR/server.key"
    chmod 644 "$CERT_DIR/ca.crt" "$CERT_DIR/server.crt"
    
    echo "Matchbox TLS certificates generated successfully"
else
    echo "Matchbox TLS certificates already exist, skipping generation"
fi

# Download Talos assets for Matchbox
echo ""
echo "Downloading Talos assets for Matchbox..."
if [ -x "./download-talos-assets.sh" ]; then
    ./download-talos-assets.sh
else
    echo "Warning: download-talos-assets.sh not found or not executable"
    echo "You'll need to manually download Talos kernel and initramfs files"
fi

echo ""
echo "Setup complete. You can now run: docker-compose up -d"