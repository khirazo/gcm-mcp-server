# API Key Management Guide

> ⚠️ **Deprecated — Not required for GCM 2.0.2 and later**
>
> GCM 2.0.2+ includes a built-in MCP server. The relay server's API key management described here is only needed for GCM versions older than 2.0.2.
>
> **If you are on GCM 2.0.2 or later, see [gcm-api-samples/mcp_bob](https://github.com/IBM/gcm-api-samples/tree/main/mcp_bob) to connect Bob IDE directly to GCM using a GCM-issued API key.**

This guide provides detailed information about API key management operations, automation, and integration patterns for the GCM MCP Server.

## Table of Contents

- [API Reference](#api-reference)
- [Key Store Internals](#key-store-internals)
- [Automation Examples](#automation-examples)
- [Integration Patterns](#integration-patterns)
- [Security Deep Dive](#security-deep-dive)
- [Operational Procedures](#operational-procedures)

---

## API Reference

### Admin Endpoints

All admin endpoints are **localhost-only** and do not require API key authentication.

#### Allowed Source IPs

```python
_ADMIN_ALLOWED_IPS = {"127.0.0.1", "::1", "localhost", "172.17.0.1"}
```

- `127.0.0.1` - IPv4 localhost
- `::1` - IPv6 localhost
- `localhost` - Hostname resolution
- `172.17.0.1` - Docker bridge (host → container access)

---

### POST /admin/keys - Create API Key

Generate a new API key for a user.

**Request:**
```http
POST /admin/keys HTTP/1.1
Host: localhost:8002
Content-Type: application/json

{
  "user": "alice"
}
```

**Response (201 Created):**
```json
{
  "key": "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2",
  "user": "alice",
  "created": "2024-01-15T10:30:00.000000+00:00",
  "key_prefix": "a1b2c3d4"
}
```

**Error Responses:**

```json
// 400 Bad Request - Missing user field
{
  "error": "Bad Request",
  "message": "'user' field is required"
}

// 403 Forbidden - Not from localhost
{
  "error": "Forbidden",
  "message": "Admin endpoints are localhost only"
}
```

**Implementation Details:**
- Key generation: `secrets.token_hex(32)` (64 hex characters)
- Hash algorithm: SHA-256
- Key prefix: First 8 characters of raw key
- Storage: Immediate write to `/data/keys.json` with 0600 permissions

**cURL Example:**
```bash
curl -X POST http://localhost:8002/admin/keys \
  -H "Content-Type: application/json" \
  -d '{"user":"alice"}' \
  -w "\n"
```

---

### GET /admin/keys - List API Keys

List all active API keys (metadata only, no raw keys or hashes).

**Request:**
```http
GET /admin/keys HTTP/1.1
Host: localhost:8002
```

**Response (200 OK):**
```json
[
  {
    "key_prefix": "a1b2c3d4",
    "user": "alice",
    "created": "2024-01-15T10:30:00.000000+00:00"
  },
  {
    "key_prefix": "x7y8z9a0",
    "user": "bob",
    "created": "2024-01-15T11:45:00.000000+00:00"
  }
]
```

**Error Responses:**

```json
// 403 Forbidden - Not from localhost
{
  "error": "Forbidden",
  "message": "Admin endpoints are localhost only"
}
```

**cURL Example:**
```bash
curl http://localhost:8002/admin/keys | jq
```

---

### DELETE /admin/keys/{key_prefix} - Revoke API Key

Revoke an API key by its prefix (first 8 characters).

**Request:**
```http
DELETE /admin/keys/a1b2c3d4 HTTP/1.1
Host: localhost:8002
```

**Response (200 OK):**
```json
{
  "status": "revoked",
  "key_prefix": "a1b2c3d4",
  "user": "alice"
}
```

**Error Responses:**

```json
// 404 Not Found - Key prefix not found
{
  "error": "Not Found",
  "message": "No key with prefix 'a1b2c3d4'"
}

// 403 Forbidden - Not from localhost
{
  "error": "Forbidden",
  "message": "Admin endpoints are localhost only"
}
```

**cURL Example:**
```bash
curl -X DELETE http://localhost:8002/admin/keys/a1b2c3d4
```

---

## Key Store Internals

### File Structure

**Location:** `/data/keys.json` (configurable via `GCM_MCP_KEY_STORE_PATH`)

**Format:**
```json
{
  "keys": {
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855": {
      "user": "alice",
      "created": "2024-01-15T10:30:00.000000+00:00",
      "key_prefix": "a1b2c3d4"
    },
    "d7a8fbb307d7809469ca9abcb0082e4f8d5651e46d3cdb762d02d0bf37c9e592": {
      "user": "bob",
      "created": "2024-01-15T11:45:00.000000+00:00",
      "key_prefix": "x7y8z9a0"
    }
  }
}
```

**Key Points:**
- Keys indexed by SHA-256 hash (64 hex characters)
- Raw keys never stored (shown once during generation)
- File permissions: `0600` (owner read/write only)
- Thread-safe operations via `threading.Lock()`

### Hash Generation

```python
import hashlib

def _hash_key(raw_key: str) -> str:
    """SHA-256 hash a raw API key."""
    return hashlib.sha256(raw_key.encode()).hexdigest()
```

**Properties:**
- Algorithm: SHA-256
- No salt (keys have high entropy from `secrets.token_hex(32)`)
- Deterministic (same key → same hash)
- One-way (hash → key is computationally infeasible)

### Key Prefix

```python
def _key_prefix(raw_key: str) -> str:
    """First 8 characters of the raw key."""
    return raw_key[:8]
```

**Purpose:**
- Human-readable identifier for key management
- Used in revocation operations
- Included in list responses
- Not cryptographically significant

### File Operations

**Load:**
```python
def _load_store() -> dict:
    """Load key store from disk."""
    path = Path(KEY_STORE_PATH)
    if not path.exists():
        return {"keys": {}}
    with open(path, "r") as f:
        return json.load(f)
```

**Save:**
```python
def _save_store(store: dict) -> None:
    """Persist key store to disk."""
    path = Path(KEY_STORE_PATH)
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w") as f:
        json.dump(store, f, indent=2)
    os.chmod(KEY_STORE_PATH, 0o600)  # Owner read/write only
```

**Thread Safety:**
```python
_lock = threading.Lock()

with _lock:
    store = _load_store()
    # ... modify store ...
    _save_store(store)
```

---

## Automation Examples

### Bash Script - Batch Key Generation

```bash
#!/bin/bash
# generate-keys.sh - Generate API keys for multiple users

USERS=("alice" "bob" "charlie" "david")
OUTPUT_FILE="api-keys.txt"

echo "Generating API keys..." > "$OUTPUT_FILE"
echo "Generated at: $(date)" >> "$OUTPUT_FILE"
echo "---" >> "$OUTPUT_FILE"

for user in "${USERS[@]}"; do
    echo "Generating key for $user..."
    
    response=$(curl -s -X POST http://localhost:8002/admin/keys \
        -H "Content-Type: application/json" \
        -d "{\"user\":\"$user\"}")
    
    key=$(echo "$response" | jq -r '.key')
    prefix=$(echo "$response" | jq -r '.key_prefix')
    
    echo "User: $user" >> "$OUTPUT_FILE"
    echo "Key: $key" >> "$OUTPUT_FILE"
    echo "Prefix: $prefix" >> "$OUTPUT_FILE"
    echo "---" >> "$OUTPUT_FILE"
    
    echo "✓ Generated key for $user (prefix: $prefix)"
done

echo ""
echo "Keys saved to $OUTPUT_FILE"
echo "⚠️  Store this file securely and delete after distribution!"
```

### Python Script - Key Management

```python
#!/usr/bin/env python3
"""
key-manager.py - Automated API key management
"""

import json
import requests
from typing import Optional

BASE_URL = "http://localhost:8002"

def create_key(user: str) -> dict:
    """Generate a new API key."""
    response = requests.post(
        f"{BASE_URL}/admin/keys",
        json={"user": user}
    )
    response.raise_for_status()
    return response.json()

def list_keys() -> list:
    """List all active keys."""
    response = requests.get(f"{BASE_URL}/admin/keys")
    response.raise_for_status()
    return response.json()

def revoke_key(prefix: str) -> dict:
    """Revoke a key by prefix."""
    response = requests.delete(f"{BASE_URL}/admin/keys/{prefix}")
    response.raise_for_status()
    return response.json()

def find_key_by_user(user: str) -> Optional[dict]:
    """Find a key by username."""
    keys = list_keys()
    for key in keys:
        if key["user"] == user:
            return key
    return None

# Example usage
if __name__ == "__main__":
    # Generate key
    result = create_key("alice")
    print(f"Generated key: {result['key']}")
    print(f"Prefix: {result['key_prefix']}")
    
    # List all keys
    keys = list_keys()
    print(f"\nActive keys: {len(keys)}")
    for key in keys:
        print(f"  - {key['user']} ({key['key_prefix']})")
    
    # Find specific user
    alice_key = find_key_by_user("alice")
    if alice_key:
        print(f"\nAlice's key prefix: {alice_key['key_prefix']}")
    
    # Revoke key
    # revoke_key(alice_key['key_prefix'])
```

### Docker Compose - Automated Key Generation

```yaml
# docker-compose.yml
services:
  gcm-mcp-server:
    image: gcm-mcp-server:latest
    # ... other config ...
  
  key-generator:
    image: curlimages/curl:latest
    depends_on:
      - gcm-mcp-server
    command: >
      sh -c "
        sleep 5 &&
        curl -X POST http://gcm-mcp-server:8002/admin/keys
          -H 'Content-Type: application/json'
          -d '{\"user\":\"default\"}'
      "
    restart: "no"
```

### Kubernetes Job - Initial Key Setup

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: gcm-mcp-key-setup
  namespace: gcm-mcp
spec:
  template:
    spec:
      containers:
      - name: key-generator
        image: curlimages/curl:latest
        command:
        - sh
        - -c
        - |
          # Wait for server to be ready
          until curl -s http://gcm-mcp-server:8002/health; do
            echo "Waiting for server..."
            sleep 2
          done
          
          # Generate keys for users
          for user in alice bob charlie; do
            echo "Generating key for $user..."
            curl -X POST http://gcm-mcp-server:8002/admin/keys \
              -H "Content-Type: application/json" \
              -d "{\"user\":\"$user\"}"
          done
      restartPolicy: Never
  backoffLimit: 3
```

---

## Integration Patterns

### Secret Manager Integration

#### HashiCorp Vault

```python
import hvac
import requests

# Initialize Vault client
vault_client = hvac.Client(url='http://vault:8200', token='...')

# Generate API key
response = requests.post(
    "http://localhost:8002/admin/keys",
    json={"user": "alice"}
)
key_data = response.json()

# Store in Vault
vault_client.secrets.kv.v2.create_or_update_secret(
    path='gcm-mcp/keys/alice',
    secret={
        'api_key': key_data['key'],
        'key_prefix': key_data['key_prefix'],
        'created': key_data['created']
    }
)

print(f"Key stored in Vault: gcm-mcp/keys/alice")
```

#### AWS Secrets Manager

```python
import boto3
import json
import requests

# Initialize AWS client
secrets_client = boto3.client('secretsmanager', region_name='us-east-1')

# Generate API key
response = requests.post(
    "http://localhost:8002/admin/keys",
    json={"user": "alice"}
)
key_data = response.json()

# Store in AWS Secrets Manager
secrets_client.create_secret(
    Name='gcm-mcp/api-keys/alice',
    SecretString=json.dumps({
        'api_key': key_data['key'],
        'key_prefix': key_data['key_prefix'],
        'user': key_data['user'],
        'created': key_data['created']
    })
)

print("Key stored in AWS Secrets Manager")
```

### CI/CD Pipeline Integration

#### GitHub Actions

```yaml
name: Generate MCP API Key

on:
  workflow_dispatch:
    inputs:
      username:
        description: 'Username for API key'
        required: true

jobs:
  generate-key:
    runs-on: ubuntu-latest
    steps:
      - name: Port forward to MCP server
        run: |
          kubectl port-forward -n gcm-mcp svc/gcm-mcp-server 8002:8002 &
          sleep 5
      
      - name: Generate API key
        id: generate
        run: |
          response=$(curl -X POST http://localhost:8002/admin/keys \
            -H "Content-Type: application/json" \
            -d "{\"user\":\"${{ github.event.inputs.username }}\"}")
          
          echo "key=$(echo $response | jq -r '.key')" >> $GITHUB_OUTPUT
          echo "prefix=$(echo $response | jq -r '.key_prefix')" >> $GITHUB_OUTPUT
      
      - name: Store in GitHub Secrets
        uses: gliech/create-github-secret-action@v1
        with:
          name: MCP_API_KEY_${{ github.event.inputs.username }}
          value: ${{ steps.generate.outputs.key }}
          pa_token: ${{ secrets.PA_TOKEN }}
```

### Monitoring Integration

#### Prometheus Metrics (Custom Exporter)

```python
from prometheus_client import Counter, Gauge, start_http_server
import requests
import time

# Metrics
keys_total = Gauge('gcm_mcp_keys_total', 'Total number of active API keys')
keys_created = Counter('gcm_mcp_keys_created_total', 'Total keys created')
keys_revoked = Counter('gcm_mcp_keys_revoked_total', 'Total keys revoked')

def collect_metrics():
    """Collect metrics from MCP server."""
    try:
        response = requests.get('http://localhost:8002/admin/keys')
        keys = response.json()
        keys_total.set(len(keys))
    except Exception as e:
        print(f"Error collecting metrics: {e}")

if __name__ == '__main__':
    start_http_server(9090)
    while True:
        collect_metrics()
        time.sleep(60)
```

---

## Security Deep Dive

### Cryptographic Properties

**Key Generation:**
- Source: `secrets.token_hex(32)`
- Entropy: 256 bits (32 bytes × 8 bits/byte)
- Character set: Hexadecimal (0-9, a-f)
- Length: 64 characters
- Collision probability: ~10^-77 (negligible)

**Hash Function:**
- Algorithm: SHA-256
- Output: 64 hexadecimal characters
- Properties: Pre-image resistant, collision resistant
- No salt: Not needed due to high key entropy

### Attack Vectors and Mitigations

| Attack Vector | Risk | Mitigation |
|--------------|------|------------|
| Brute force | Low | 256-bit entropy makes brute force infeasible |
| Rainbow tables | None | No salt needed (keys are random, not passwords) |
| Timing attacks | Low | Constant-time comparison not implemented (acceptable for API keys) |
| Key leakage | High | Keys shown once, never logged, stored as hashes |
| Admin endpoint exposure | High | Localhost-only enforcement, network policies |
| File permission bypass | Medium | 0600 permissions, container user isolation |

### Compliance Considerations

**GDPR:**
- User field may contain PII (use IDs instead of names)
- Key revocation provides "right to be forgotten"
- Audit logs should track key operations

**SOC 2:**
- Key rotation policies required
- Access logging recommended
- Secure key distribution process needed

**PCI DSS:**
- Keys are not payment card data
- Standard security practices apply
- Encryption in transit recommended (HTTPS)

---

## Operational Procedures

### Key Rotation

**Recommended Schedule:**
- Development: 90 days
- Staging: 60 days
- Production: 30 days

**Rotation Procedure:**

```bash
#!/bin/bash
# rotate-key.sh - Rotate API key for a user

USER=$1
GRACE_PERIOD_HOURS=${2:-24}

if [ -z "$USER" ]; then
    echo "Usage: $0 <username> [grace_period_hours]"
    exit 1
fi

# Find existing key
OLD_KEY=$(curl -s http://localhost:8002/admin/keys | \
    jq -r ".[] | select(.user==\"$USER\") | .key_prefix")

if [ -z "$OLD_KEY" ]; then
    echo "No existing key found for user: $USER"
    exit 1
fi

echo "Found existing key: $OLD_KEY"

# Generate new key
echo "Generating new key for $USER..."
NEW_KEY_DATA=$(curl -s -X POST http://localhost:8002/admin/keys \
    -H "Content-Type: application/json" \
    -d "{\"user\":\"$USER\"}")

NEW_KEY=$(echo "$NEW_KEY_DATA" | jq -r '.key')
NEW_PREFIX=$(echo "$NEW_KEY_DATA" | jq -r '.key_prefix')

echo "New key generated: $NEW_PREFIX"
echo "Raw key: $NEW_KEY"
echo ""
echo "⚠️  Update client configuration with new key"
echo "⚠️  Old key ($OLD_KEY) will be revoked in $GRACE_PERIOD_HOURS hours"
echo ""
echo "To revoke old key now:"
echo "  curl -X DELETE http://localhost:8002/admin/keys/$OLD_KEY"
echo ""
echo "To schedule automatic revocation:"
echo "  echo \"curl -X DELETE http://localhost:8002/admin/keys/$OLD_KEY\" | at now + $GRACE_PERIOD_HOURS hours"
```

### Backup and Recovery

**Backup:**
```bash
#!/bin/bash
# backup-keys.sh - Backup key store

BACKUP_DIR="/backup/gcm-mcp-keys"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

# Copy key store
docker cp gcm-mcp-server:/data/keys.json \
    "$BACKUP_DIR/keys_$TIMESTAMP.json"

# Encrypt backup
gpg --encrypt --recipient admin@example.com \
    "$BACKUP_DIR/keys_$TIMESTAMP.json"

# Remove unencrypted backup
rm "$BACKUP_DIR/keys_$TIMESTAMP.json"

echo "Backup created: $BACKUP_DIR/keys_$TIMESTAMP.json.gpg"
```

**Recovery:**
```bash
#!/bin/bash
# restore-keys.sh - Restore key store from backup

BACKUP_FILE=$1

if [ -z "$BACKUP_FILE" ]; then
    echo "Usage: $0 <backup_file.json.gpg>"
    exit 1
fi

# Decrypt backup
gpg --decrypt "$BACKUP_FILE" > /tmp/keys.json

# Stop server
docker-compose stop gcm-mcp-server

# Restore key store
docker cp /tmp/keys.json gcm-mcp-server:/data/keys.json

# Fix permissions
docker exec gcm-mcp-server chmod 600 /data/keys.json

# Start server
docker-compose start gcm-mcp-server

# Clean up
rm /tmp/keys.json

echo "Key store restored from $BACKUP_FILE"
```

### Audit Logging

**Log Key Operations:**

```python
import logging
from datetime import datetime

logger = logging.getLogger('gcm-mcp-audit')
logger.setLevel(logging.INFO)

# File handler for audit log
handler = logging.FileHandler('/var/log/gcm-mcp-audit.log')
handler.setFormatter(logging.Formatter(
    '%(asctime)s - %(levelname)s - %(message)s'
))
logger.addHandler(handler)

def audit_key_created(user: str, key_prefix: str, client_ip: str):
    """Log key creation."""
    logger.info(f"KEY_CREATED user={user} prefix={key_prefix} client={client_ip}")

def audit_key_revoked(user: str, key_prefix: str, client_ip: str):
    """Log key revocation."""
    logger.info(f"KEY_REVOKED user={user} prefix={key_prefix} client={client_ip}")

def audit_auth_failed(client_ip: str, path: str):
    """Log failed authentication."""
    logger.warning(f"AUTH_FAILED client={client_ip} path={path}")
```

**Parse Audit Logs:**

```bash
# Count key operations by user
grep "KEY_CREATED" /var/log/gcm-mcp-audit.log | \
    awk '{print $5}' | sort | uniq -c

# Find failed auth attempts
grep "AUTH_FAILED" /var/log/gcm-mcp-audit.log | \
    awk '{print $4}' | sort | uniq -c | sort -rn

# Recent key revocations
grep "KEY_REVOKED" /var/log/gcm-mcp-audit.log | tail -10
```

---

## Related Documentation

- [Authentication Guide](../AUTHENTICATION.md) - Main authentication documentation
- [Client Configuration Guide](client-configuration.md) - MCP client setup examples
- [Server README](../README.md) - Server overview and setup

---

## Support

For API key management issues:

1. Check server logs for error messages
2. Verify localhost access (admin endpoints)
3. Confirm file permissions on `/data/keys.json`
4. Review this guide's troubleshooting sections

**Security issues**: Report privately to maintainers.