# Bug Fixes Applied to omni-docker

This document lists all the bugs encountered during deployment and their fixes.

## 1. Token Renewal Time Calculation (vault-cert-manager.sh)
**Issue**: Token renewal was using a fixed 50% calculation instead of flexible time parsing.
**Fix**: Added `parse_time_to_seconds()` function that supports formats like "7d", "168h", "1d6h30m".

## 2. Graceful Vault Unavailability Handling (vault-cert-manager.sh)
**Issue**: Script would fail immediately if Vault was unavailable at startup.
**Fix**: Added `wait_for_vault()` function with exponential backoff (max 10 attempts, up to 5 minutes wait).

## 3. CSR Generation Failure (vault-cert-manager.sh)
**Issue**: Certificate signing request was empty, causing Vault certificate requests to fail.
**Fix**: Added complete CSR generation with private key creation and proper CSR configuration.

## 4. Health Check Certificate Filename Mismatch (docker-compose files)
**Issue**: Health check was looking for cert.pem/key.pem but vault-cert-manager creates server.crt/server.key.
**Fix**: Updated health check to use correct filenames:
```yaml
test: ["CMD", "sh", "-c", "test -f /etc/nginx/ssl/server.crt && test -f /etc/nginx/ssl/server.key"]
```

## 5. Omni Siderolink Binding Issue (docker-compose files)
**Issue**: Using deprecated `--siderolink-api-bind-addr` flag and IPv6 binding conflicts.
**Fix**: Changed to `--machine-api-bind-addr` and `--machine-api-advertised-url`.

## 6. Network Optimization (docker-compose files)
**Issue**: All containers were on macvlan network, consuming multiple IPs.
**Fix**: Only nginx on macvlan (192.168.1.8), other containers on internal bridge network.

## 7. Matchbox Assets Path (docker-compose files)
**Issue**: Matchbox wasn't serving static assets.
**Fix**: Added `-assets-path=/var/lib/matchbox/assets` to Matchbox command.

## 8. Matchbox TLS Configuration
**Issue**: Initial confusion about HTTP vs gRPC TLS requirements.
**Clarification**: Matchbox serves HTTP on port 8088 without TLS (for iPXE) and gRPC on port 8081 with TLS.

## 9. Docker Compose Version Deprecation
**Issue**: Warning about obsolete `version` attribute.
**Fix**: Removed `version: '3.8'` from docker-compose files.

## 10. RENEW_BEFORE Documentation (README.md, docker-compose files)
**Issue**: Missing documentation for certificate renewal time formats.
**Fix**: Added comprehensive documentation in docker-compose files explaining supported formats.

## 11. Alpine Linux Date Command Compatibility (vault-cert-manager.sh)
**Issue**: Alpine's BusyBox date command doesn't support `-d` flag.
**Fix**: Used arithmetic operations for time calculations instead of date parsing.

## 12. GPG Key Generation (omni.asc)
**Issue**: Missing GPG key for Omni etcd encryption.
**Fix**: Generated proper GPG key with certification and encryption capabilities.

## Summary

All bugs have been fixed in the code. The deployment now works reliably with:
- Automatic certificate management with Vault
- Proper health checks and startup dependencies
- Optimized networking with single external IP
- Working Matchbox PXE boot server with Talos assets
- Graceful handling of service unavailability