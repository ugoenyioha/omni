# Certificate Architecture

## Overview

The deployment uses two separate certificate systems:

### 1. Nginx Certificates (from Vault)
- **Location**: `/etc/nginx/ssl/`
- **Files**: `server.crt`, `server.key`
- **Purpose**: HTTPS termination for all web traffic
- **Domains**: `*.home.usableapps.io`
- **Management**: Automatic renewal via vault-cert-manager

### 2. Matchbox Certificates (self-signed)
- **Location**: `/etc/matchbox/`
- **Files**: `server.crt`, `server.key`, `ca.crt`, `client.crt`, `client.key`
- **Purpose**: gRPC API authentication
- **Management**: Pre-generated, included in repo

## Why Separate Certificates?

### Nginx Needs:
- Valid certificates for HTTPS (browsers)
- Covers all service domains
- Automatic renewal from Vault

### Matchbox Needs:
- Self-signed certificates are fine (internal gRPC)
- Client certificate authentication
- Only used for management API, not PXE boot

## Important Notes

1. **PXE Boot**: Happens over HTTP (port 80), no certificates needed
2. **Web Access**: All HTTPS handled by Nginx with Vault certs
3. **gRPC API**: Matchbox gRPC (port 8081) uses its own certs
4. **Separation**: Keeping them separate allows:
   - Vault to manage public-facing certs
   - Matchbox to use stable self-signed certs for API

## Could They Be Unified?

Technically yes, but:
- Matchbox expects specific certificate paths
- Matchbox needs client certificates for authentication
- Vault issues server certificates, not client certificates
- Current setup works well with clear separation of concerns