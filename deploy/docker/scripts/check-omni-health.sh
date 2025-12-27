#!/bin/bash
# External health check script for Omni
# Run this from the host or another container

OMNI_IP=$(docker inspect sidero-omni --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null)

if [ -z "$OMNI_IP" ]; then
    echo "ERROR: Omni container not found or not running"
    exit 1
fi

# Check HTTP health endpoint
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://${OMNI_IP}:8080/healthz 2>/dev/null)

if [ "$HTTP_STATUS" = "200" ]; then
    echo "OK: Omni healthz endpoint returned 200"
else
    echo "ERROR: Omni healthz endpoint returned $HTTP_STATUS"
    exit 1
fi

# Check if the container is running
if docker ps | grep -q sidero-omni; then
    echo "OK: Omni container is running"
else
    echo "ERROR: Omni container is not running"
    exit 1
fi

# Check for recent errors in logs
ERRORS=$(docker logs sidero-omni --since=5m 2>&1 | grep -iE "(error|panic|fatal)" | wc -l)
if [ "$ERRORS" -gt 0 ]; then
    echo "WARNING: Found $ERRORS errors in recent logs"
    docker logs sidero-omni --since=5m 2>&1 | grep -iE "(error|panic|fatal)" | tail -5
else
    echo "OK: No errors in recent logs"
fi

echo "Overall: Omni appears healthy"