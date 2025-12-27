#!/bin/bash
set -e

# Configuration
WATCH_DIR="/etc/nginx/ssl"
WATCH_FILE=".updated"
NGINX_PID=1  # nginx will be pid 1 in shared namespace

echo "Starting nginx certificate reload watcher..."
echo "Watching for: $WATCH_DIR/$WATCH_FILE"

# Function to reload nginx
reload_nginx() {
    echo "Certificate update detected at $(date)"
    
    # Send SIGHUP to nginx to reload configuration
    if kill -HUP $NGINX_PID 2>/dev/null; then
        echo "Successfully sent reload signal to nginx (PID $NGINX_PID)"
    else
        echo "ERROR: Failed to send reload signal to nginx"
        return 1
    fi
    
    # Remove the .updated file
    if rm -f "$WATCH_DIR/$WATCH_FILE" 2>/dev/null; then
        echo "Removed $WATCH_FILE marker"
    else
        echo "WARNING: Could not remove $WATCH_FILE marker"
    fi
    
    return 0
}

# Main monitoring loop
while true; do
    # Check if the watch directory exists
    if [ ! -d "$WATCH_DIR" ]; then
        echo "WARNING: Watch directory $WATCH_DIR does not exist, waiting..."
        sleep 10
        continue
    fi
    
    # Use inotifywait to monitor for the .updated file
    # -e create: watch for file creation
    # -e modify: watch for file modification
    # -e moved_to: watch for files moved into the directory
    inotifywait -e create -e modify -e moved_to "$WATCH_DIR" 2>/dev/null | while read path action file; do
        if [ "$file" = "$WATCH_FILE" ]; then
            echo "Detected $action event on $file"
            
            # Small delay to ensure file write is complete
            sleep 1
            
            # Reload nginx
            reload_nginx
        fi
    done
    
    # If inotifywait exits (shouldn't happen), wait before restarting
    echo "WARNING: inotifywait exited unexpectedly, restarting in 5 seconds..."
    sleep 5
done