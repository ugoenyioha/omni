# Shell Scripts Overview

## Active Scripts (Keep These)

### 1. `setup.sh`
- **Purpose**: Initial setup - creates required directories and generates GPG key
- **When to use**: Must be run first before any deployment
- **Used by**: Both Arch Linux and QNAP deployments
- **Creates**:
  - `data/` - Omni etcd data directory
  - `_out/` - Omni output directory
  - `matchbox/data/profiles/` - Matchbox profiles
  - `matchbox/data/groups/` - Matchbox groups
  - `matchbox/data/assets/talos/` - Talos kernel storage
  - `omni.asc` - GPG encryption key for etcd

### 2. `setup-vault-auth.sh`
- **Purpose**: Configure Vault authentication for SSL certificates
- **When to use**: Before deployment to get vault-token
- **Required for**: Certificate management via Vault

### 3. `deploy-to-qnap.sh`
- **Purpose**: Automated deployment to QNAP Container Station
- **When to use**: Deploying to QNAP
- **Features**: Builds images, creates network, uploads, deploys

### 4. `create-qnap-network.sh`
- **Purpose**: Create macvlan network on QNAP
- **When to use**: Run on QNAP via SSH
- **Called by**: deploy-to-qnap.sh

### 5. `update-matchbox-profile.sh`
- **Purpose**: Update Matchbox with Omni kernel parameters
- **When to use**: After getting parameters from Omni dashboard
- **Critical for**: PXE boot functionality

### 6. `update-containers.sh`
- **Purpose**: Manual container updates
- **When to use**: When you want to control updates manually
- **Features**: Check, update all, or update specific containers

## Removed Scripts (No Longer Needed)

- `add-vip.sh` - Was for VIP setup, now using macvlan
- `deploy-omni.sh` - Old deployment script, replaced by docker-compose
- `generate-certs.sh` - Now using Vault for certificates
- `setup-qnap.sh` - Replaced by deploy-to-qnap.sh
- `temp_setup.sh` - Temporary file
- `temp_setup2.sh` - Temporary file

## Script Dependencies

```
Initial Setup:
├── setup.sh (Creates directories + GPG key)
└── setup-vault-auth.sh (Vault token)

QNAP Deployment:
├── deploy-to-qnap.sh
│   └── create-qnap-network.sh (runs on QNAP)

Post-Deployment:
├── update-matchbox-profile.sh (kernel params)
└── update-containers.sh (maintenance)
```