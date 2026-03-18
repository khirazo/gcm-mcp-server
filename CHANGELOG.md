# Changelog - GCM MCP Server

All notable changes to the GCM MCP Server core functionality.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added
- **Separate OIDC Provider Host Support**: GCM API and OIDC provider (e.g., Keycloak) can now be on different hosts
  - New environment variables: `GCM_OIDC_HOST` and `GCM_OIDC_PORT`
  - Enables flexible deployment scenarios (OpenShift, Kubernetes with external IdP)
  - Backward compatible with existing `GCM_KEYCLOAK_*` variables

### Changed
- **src/config.py**:
  - Added `GCM_OIDC_HOST` and `GCM_OIDC_PORT` configuration variables
  - Implemented fallback chain: `GCM_OIDC_*` → `GCM_KEYCLOAK_*` (deprecated) → `GCM_HOST`
  - `GCM_KEYCLOAK_PORT` now acts as an alias to `GCM_OIDC_PORT`

- **src/client.py**:
  - Added `oidc_host` and `oidc_port` parameters to `GCMClient.__init__()`
  - OIDC URL now constructed independently from GCM API URL
  - Formula: `https://{oidc_host}:{oidc_port}` (previously used same host as GCM API)
  - Maintains backward compatibility with `keycloak_port` parameter

- **src/auth.py**:
  - Updated documentation to use "OIDC Provider" terminology instead of "Keycloak"
  - Added notes about separate host support in docstrings
  - Clarified that OIDC Provider can be on a different host from GCM API

### Deprecated
- `GCM_KEYCLOAK_PORT` environment variable (use `GCM_OIDC_PORT` instead)
- `keycloak_port` parameter in `GCMClient.__init__()` (use `oidc_port` instead)

**Note**: Deprecated features will continue to work indefinitely for backward compatibility.

## Configuration Examples

### Same Host (Default Behavior)
```bash
GCM_HOST=gcm.example.com
# OIDC provider defaults to same host
```

### Separate Hosts (OpenShift, External IdP)
```bash
GCM_HOST=gcm-api.example.com
GCM_OIDC_HOST=keycloak.example.com
GCM_OIDC_PORT=30443
```

### Backward Compatible (Still Works)
```bash
GCM_HOST=gcm.example.com
GCM_KEYCLOAK_PORT=30443  # Deprecated but functional
```

## Migration Guide

If you're using `GCM_KEYCLOAK_*` variables, consider migrating to `GCM_OIDC_*`:

**Before:**
```bash
GCM_KEYCLOAK_PORT=30443
```

**After:**
```bash
GCM_OIDC_PORT=30443
```

No code changes required - the old variables continue to work.