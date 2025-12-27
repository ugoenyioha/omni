#!/bin/bash
# Backup script for Omni before OIDC deployment
# Run this BEFORE deploying the new version

set -e

BACKUP_DIR="$HOME/omni-backup"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

echo "=== Omni Pre-Deployment Backup Script ==="
echo "Timestamp: $TIMESTAMP"
echo "Backup directory: $BACKUP_DIR"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

echo ""
echo "1. Backing up Docker images..."
# Check if images exist before backing up
if docker images | grep -q "omni-with-certs.*latest"; then
    echo "   - Backing up omni-with-certs:latest"
    docker save omni-with-certs:latest -o "$BACKUP_DIR/omni-with-certs-$TIMESTAMP.tar"
    docker tag omni-with-certs:latest omni-with-certs:stable-$TIMESTAMP
fi

if docker images | grep -q "omni-push-to-matchbox.*latest"; then
    echo "   - Backing up omni-push-to-matchbox:latest"
    docker save omni-push-to-matchbox:latest -o "$BACKUP_DIR/omni-push-to-matchbox-$TIMESTAMP.tar"
    docker tag omni-push-to-matchbox:latest omni-push-to-matchbox:stable-$TIMESTAMP
fi

echo ""
echo "2. Backing up etcd data..."
# Create etcd snapshot
if docker ps | grep -q omni-etcd; then
    docker exec omni-etcd etcdctl \
        --endpoints=https://localhost:2379 \
        --cert=/etc/ssl/server.crt \
        --key=/etc/ssl/server.key \
        --insecure-skip-tls-verify \
        snapshot save /tmp/backup-$TIMESTAMP.db
    
    docker cp omni-etcd:/tmp/backup-$TIMESTAMP.db "$BACKUP_DIR/etcd-snapshot-$TIMESTAMP.db"
    docker exec omni-etcd rm /tmp/backup-$TIMESTAMP.db
    echo "   - etcd snapshot saved to $BACKUP_DIR/etcd-snapshot-$TIMESTAMP.db"
else
    echo "   WARNING: omni-etcd container not running, skipping etcd backup"
fi

echo ""
echo "3. Backing up configuration files..."
# Backup docker-compose files
for file in ~/omni-docker/*.yml ~/omni-docker/*.yaml; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        cp "$file" "$BACKUP_DIR/${filename%.yml}-$TIMESTAMP.yml"
        echo "   - Backed up $filename"
    fi
done

echo ""
echo "4. Recording current container status..."
docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" | grep -E "omni|etcd" > "$BACKUP_DIR/container-status-$TIMESTAMP.txt" || true
echo "   - Container status saved to $BACKUP_DIR/container-status-$TIMESTAMP.txt"

echo ""
echo "5. Testing current Omni health..."
# Test current Omni is working
if curl -sk https://localhost:443/api/v1/auth/info -o /dev/null -w "%{http_code}" | grep -q "200"; then
    echo "   ✓ Current Omni is healthy (HTTP 200)"
else
    echo "   ⚠ WARNING: Current Omni may not be healthy"
    read -p "   Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborting backup. Please check Omni health first."
        exit 1
    fi
fi

echo ""
echo "6. Creating restore script..."
cat > "$BACKUP_DIR/restore-$TIMESTAMP.sh" << 'EOF'
#!/bin/bash
# Auto-generated restore script
TIMESTAMP=EOF
echo "$TIMESTAMP" >> "$BACKUP_DIR/restore-$TIMESTAMP.sh"
cat >> "$BACKUP_DIR/restore-$TIMESTAMP.sh" << 'EOF'

echo "=== Omni Restore Script ==="
echo "This will restore Omni to the state from $TIMESTAMP"
read -p "Are you sure you want to restore? (yes/no) " -r
if [[ ! $REPLY == "yes" ]]; then
    echo "Restore cancelled"
    exit 1
fi

echo "Stopping current Omni..."
docker stop sidero-omni 2>/dev/null || true
docker rm sidero-omni 2>/dev/null || true

echo "Restoring Docker images..."
docker load -i "omni-with-certs-$TIMESTAMP.tar"
docker load -i "omni-push-to-matchbox-$TIMESTAMP.tar"

echo "Restoring configuration..."
cp "docker-compose-arch-$TIMESTAMP.yml" ~/omni-docker/docker-compose-arch.yml

echo "Starting Omni with restored configuration..."
cd ~/omni-docker
docker-compose -f docker-compose-arch.yml up -d

echo "Restore complete! Check logs with: docker logs -f sidero-omni"
EOF

chmod +x "$BACKUP_DIR/restore-$TIMESTAMP.sh"
echo "   - Restore script created: $BACKUP_DIR/restore-$TIMESTAMP.sh"

echo ""
echo "=== Backup Complete ==="
echo "Backup location: $BACKUP_DIR"
echo "Backup timestamp: $TIMESTAMP"
echo ""
echo "To restore if needed, run:"
echo "  cd $BACKUP_DIR && ./restore-$TIMESTAMP.sh"
echo ""
echo "You can now proceed with deployment."
echo "Run: ./build-and-deploy-omni.sh"