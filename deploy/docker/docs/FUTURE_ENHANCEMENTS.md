# Future Enhancements

## Automated Omni to Matchbox Sync

Currently, there is no built-in "push to Matchbox" button in Sidero Omni. The integration between Omni and Matchbox requires manual steps that could be automated.

### Current Manual Process

1. Download installation media from Omni UI (includes kernel parameters with SideroLink token)
2. Extract kernel/initramfs files manually
3. Copy files to Matchbox assets directory
4. Update Matchbox profiles with kernel parameters

### Automation Options

#### 1. Automated Sync Script

Create a script that:
- Uses `omnictl download` CLI to fetch installation media
- Automatically extracts and places files in Matchbox
- Updates Matchbox profiles with parameters
- Can be run as a cron job or triggered manually

Example omnictl commands:
```bash
# Get PXE URLs directly
omnictl download --arch amd64 --pxe

# Download to specific directory
omnictl download --arch amd64 --output /path/to/matchbox/data/assets

# Download with extensions and labels
omnictl download --arch amd64 \
  --extensions qemu-guest-agent \
  --initial-labels environment=production
```

#### 2. Webhook Endpoint

Add a webhook endpoint to nginx that:
- Receives download requests
- Triggers the sync process
- Could be called from a browser bookmarklet or automation tool
- Returns status of the sync operation

#### 3. Simple Web UI

Create a lightweight web interface that:
- Shows current Omni clusters
- Displays current Matchbox profiles
- Has a "Sync to Matchbox" button for each cluster
- Shows sync status and history
- Could be served by the existing nginx container

### Implementation Considerations

- **Authentication**: Need to handle omnictl authentication (omniconfig)
- **Multi-cluster**: Support syncing multiple clusters to different Matchbox profiles
- **Versioning**: Track which Talos version is deployed to which profile
- **Rollback**: Keep previous kernel/initramfs versions for rollback
- **Notifications**: Alert when new Talos versions are available

### Benefits

- Eliminate manual file copying
- Reduce human error in parameter configuration
- Enable automated Talos upgrades
- Provide audit trail of deployments
- Simplify cluster lifecycle management