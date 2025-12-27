# Watchtower Configuration Guide

Watchtower automatically updates Docker containers when new images are available.

## Features Configured

1. **Automatic Updates**
   - Checks for updates daily at 3 AM
   - Pulls new images automatically
   - Performs rolling restarts to minimize downtime
   - Cleans up old images after update

2. **Update Strategy**
   - Only updates running containers
   - 30-second timeout for graceful shutdown
   - Rolling restart to maintain availability

3. **Safety Features**
   - Won't update stopped containers
   - Preserves container configurations
   - Maintains volumes and data

## Controlling Updates

### Option 1: Label-based Control (Recommended for Production)

To enable selective updates, add labels to containers you want to auto-update:

```yaml
services:
  nginx:
    image: nginx:alpine
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
```

Then set Watchtower to only update labeled containers:
```yaml
environment:
  - WATCHTOWER_LABEL_ENABLE=true
```

### Option 2: Exclude Specific Containers

To exclude specific containers from updates:

```yaml
services:
  omni:
    image: ghcr.io/siderolabs/omni:v1.0.0-beta.1
    labels:
      - "com.centurylinklabs.watchtower.enable=false"
```

### Option 3: Monitor Only (No Auto-Update)

For monitoring without automatic updates:
```yaml
environment:
  - WATCHTOWER_MONITOR_ONLY=true
```

## Update Schedule Options

Current: Daily at 3 AM
```yaml
command: --schedule "0 0 3 * * *"
```

Other options:
- Every 6 hours: `--schedule "0 0 */6 * * *"`
- Weekly on Sunday: `--schedule "0 0 3 * * 0"`
- Every hour: `--schedule "0 0 * * * *"`

## Manual Updates

To trigger an update manually:
```bash
docker exec watchtower /watchtower --run-once
```

## Checking Watchtower Logs

```bash
# View recent updates
docker logs watchtower

# Follow logs
docker logs -f watchtower

# Check last 50 lines
docker logs --tail 50 watchtower
```

## Best Practices

1. **Test Updates First**
   - Use staging environment
   - Enable monitoring mode initially
   - Test rollback procedures

2. **Version Pinning**
   - Pin critical services to specific versions
   - Use tags like `v1.0.0` instead of `latest`
   - Example: `omni:v1.0.0-beta.1`

3. **Backup Before Updates**
   - Ensure data volumes are backed up
   - Document current versions
   - Have rollback plan ready

## Notifications

To enable email notifications, configure SMTP:
```yaml
environment:
  - WATCHTOWER_NOTIFICATIONS=email
  - WATCHTOWER_NOTIFICATION_EMAIL_FROM=watchtower@yourdomain.com
  - WATCHTOWER_NOTIFICATION_EMAIL_TO=admin@yourdomain.com
  - WATCHTOWER_NOTIFICATION_EMAIL_SERVER=smtp.gmail.com
  - WATCHTOWER_NOTIFICATION_EMAIL_SERVER_PORT=587
  - WATCHTOWER_NOTIFICATION_EMAIL_SERVER_USER=username
  - WATCHTOWER_NOTIFICATION_EMAIL_SERVER_PASSWORD=password
```

## Disabling Watchtower

To temporarily disable:
```bash
docker stop watchtower
```

To permanently disable:
```bash
docker-compose stop watchtower
docker-compose rm watchtower
```

## Security Considerations

1. Watchtower needs Docker socket access
2. Only pulls from authenticated registries you've logged into
3. Respects Docker credential helpers
4. Consider using read-only socket proxy for enhanced security

## Troubleshooting

### Container not updating:
- Check if container is running
- Verify image has new version available
- Check labels if using label-based control
- Review Watchtower logs

### Update failures:
- Check disk space
- Verify network connectivity
- Ensure registry access
- Review container health checks