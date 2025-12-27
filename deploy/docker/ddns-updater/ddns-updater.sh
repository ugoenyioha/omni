#!/bin/bash
set -e

# DDNS Updater with TSIG support
# Updates DNS records when container IP changes

# Configuration from environment variables
DNS_SERVER=${DNS_SERVER:-"192.168.1.29"}
DNS_ZONE=${DNS_ZONE:-"home.usableapps.io"}
DNS_TTL=${DNS_TTL:-300}
UPDATE_INTERVAL=${UPDATE_INTERVAL:-60}
TSIG_KEY_FILE=${TSIG_KEY_FILE:-"/run/secrets/tsig.key"}

# Records to update (comma-separated)
# Format: "hostname:ip_source" where ip_source can be:
# - "container" (default): Use container's IP
# - "macvlan": Use macvlan network IP
# - "x.x.x.x": Use specific IP
DNS_RECORDS=${DNS_RECORDS:-"omni:192.168.1.8,omni-siderolink:192.168.1.8,omni-k8s:192.168.1.8,matchbox:192.168.1.8"}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Function to log messages
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" >&2
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARN:${NC} $1"
}

# Function to check if TSIG key exists
check_tsig_key() {
    if [ ! -f "$TSIG_KEY_FILE" ]; then
        error "TSIG key file not found: $TSIG_KEY_FILE"
        return 1
    fi
    
    # Validate TSIG key format
    if ! grep -q "algorithm\|secret" "$TSIG_KEY_FILE"; then
        error "Invalid TSIG key format in $TSIG_KEY_FILE"
        return 1
    fi
    
    return 0
}

# Function to get container IP
get_container_ip() {
    local network=$1
    if [ -z "$network" ]; then
        # Get default route interface IP
        ip -4 addr show $(ip route | grep default | awk '{print $5}' | head -1) | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1
    else
        # Get specific network interface IP
        ip -4 addr show | grep -A2 "$network" | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1
    fi
}

# Function to get current DNS record
get_current_dns_record() {
    local hostname=$1
    local fqdn="${hostname}.${DNS_ZONE}"
    
    # Query current A record
    dig +short @${DNS_SERVER} ${fqdn} A 2>/dev/null | head -1
}

# Function to update DNS record
update_dns_record() {
    local hostname=$1
    local new_ip=$2
    local fqdn="${hostname}.${DNS_ZONE}"
    
    # Create nsupdate script
    local update_script=$(mktemp)
    cat > "$update_script" <<EOF
server ${DNS_SERVER}
zone ${DNS_ZONE}
update delete ${fqdn} A
update add ${fqdn} ${DNS_TTL} A ${new_ip}
send
EOF
    
    # Execute nsupdate with TSIG key
    if nsupdate -k "$TSIG_KEY_FILE" -v "$update_script" 2>&1; then
        log "Successfully updated ${fqdn} -> ${new_ip}"
        rm -f "$update_script"
        return 0
    else
        error "Failed to update ${fqdn}"
        rm -f "$update_script"
        return 1
    fi
}

# Function to process all records
process_records() {
    local updates_made=0
    
    # Parse DNS_RECORDS
    IFS=',' read -ra RECORDS <<< "$DNS_RECORDS"
    for record in "${RECORDS[@]}"; do
        # Parse hostname and IP source
        IFS=':' read -r hostname ip_source <<< "$record"
        
        # Skip if hostname is empty
        if [ -z "$hostname" ]; then
            continue
        fi
        
        # Determine IP address
        local new_ip=""
        if [ -z "$ip_source" ] || [ "$ip_source" = "container" ]; then
            new_ip=$(get_container_ip)
        elif [ "$ip_source" = "macvlan" ]; then
            new_ip=$(get_container_ip "macvlan")
        elif [[ "$ip_source" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            new_ip="$ip_source"
        else
            warn "Unknown IP source: $ip_source for $hostname"
            continue
        fi
        
        # Skip if we couldn't determine IP
        if [ -z "$new_ip" ]; then
            warn "Could not determine IP for $hostname"
            continue
        fi
        
        # Get current DNS record
        local current_ip=$(get_current_dns_record "$hostname")
        
        # Update if different or not set
        if [ "$current_ip" != "$new_ip" ]; then
            log "Updating $hostname: ${current_ip:-none} -> $new_ip"
            if update_dns_record "$hostname" "$new_ip"; then
                ((updates_made++))
            fi
        else
            log "$hostname is up to date: $current_ip"
        fi
    done
    
    return $updates_made
}

# Function to create a sample TSIG key
create_sample_tsig_key() {
    cat <<EOF
# Sample TSIG key file
# Key name: client2
# Algorithm: hmac-sha512
key "client2" {
    algorithm hmac-sha512;
    secret "base64-encoded-secret-here";
};
EOF
}

# Main execution
main() {
    log "Starting DDNS updater"
    log "DNS Server: $DNS_SERVER"
    log "DNS Zone: $DNS_ZONE"
    log "Update Interval: ${UPDATE_INTERVAL}s"
    
    # Check TSIG key
    if ! check_tsig_key; then
        error "TSIG key validation failed"
        echo "Sample TSIG key format:"
        create_sample_tsig_key
        exit 1
    fi
    
    log "TSIG key validated"
    
    # Main update loop
    while true; do
        log "Checking DNS records..."
        
        if process_records; then
            log "DNS update cycle completed"
        else
            warn "Some updates may have failed"
        fi
        
        # Wait for next update
        log "Sleeping for ${UPDATE_INTERVAL}s..."
        sleep "$UPDATE_INTERVAL"
    done
}

# Handle signals for graceful shutdown
trap 'log "Shutting down..."; exit 0' SIGTERM SIGINT

# Start main function
main