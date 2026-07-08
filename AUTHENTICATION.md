# Authentication Guide

> ⚠️ **Deprecated — Not required for GCM 2.0.2 and later**
>
> GCM 2.0.2+ includes a built-in MCP server with its own authentication. This relay server and the authentication described here are only needed for GCM versions older than 2.0.2.
>
> **If you are on GCM 2.0.2 or later, see [gcm-api-samples/mcp_bob](https://github.com/IBM/gcm-api-samples/tree/main/mcp_bob) to connect Bob IDE directly to GCM using a GCM-issued API key.**

## Overview

The GCM MCP Server implements a **two-layer authentication architecture** to secure both client connections and upstream GCM API access.

```mermaid
graph LR
    A[MCP Client] -->|"① API Key"| B[MCP Server]
    B -->|"② OAuth2/OIDC"| C[Keycloak]
    C -->|"③ Access Token"| B
    B -->|"④ Bearer Token"| D[GCM API]
```

### Authentication Layers

| Layer | Purpose | Method | Required For |
|-------|---------|--------|--------------|
| **Client → MCP** | Authenticate MCP clients | API Key (Bearer token) | SSE mode only |
| **MCP → GCM** | Authenticate to GCM services | OAuth2/OIDC via Keycloak | All modes |

**Important**: This guide focuses on **Layer 1 (Client → MCP)** authentication. Layer 2 is handled automatically by the server using credentials from environment variables.

---

## Transport Modes

The MCP server supports two transport modes with different authentication requirements:

### STDIO Mode
- **Authentication**: None required
- **Use Case**: Local IDE integration (direct process communication)
- **Security**: Process-level isolation
- **Command**: `python -m src --transport stdio`

### SSE Mode (HTTP)
- **Authentication**: API Key required (Bearer token)
- **Use Case**: Remote access, web-based clients
- **Security**: API key validation on every request
- **Command**: `python -m src --transport sse --host 0.0.0.0 --port 8002`

**This guide focuses on SSE mode authentication.**

---

## API Key Authentication

### How It Works

1. **Key Generation**: Admin generates API key via localhost-only endpoint
2. **Key Storage**: Server stores SHA-256 hash in `/data/keys.json` (0600 permissions)
3. **Client Usage**: Client includes key in `Authorization: Bearer <key>` header
4. **Validation**: Server validates key on every request
5. **Access Control**: Valid key grants access to all MCP endpoints

### Key Properties

- **Format**: 64-character hexadecimal string (e.g., `a1b2c3d4...`)
- **Storage**: SHA-256 hash only (raw key never persisted)
- **Visibility**: Shown only once during generation
- **Identification**: First 8 characters used as prefix for management
- **Lifecycle**: No expiration (manual revocation required)

---

## Quick Start

### Prerequisites

- MCP server running in SSE mode
- Access to server's localhost (for admin operations)
- `curl` or similar HTTP client

### Step 1: Generate API Key

**From Docker host:**
```bash
# Create key for user "alice"
curl -X POST http://localhost:8002/admin/keys \
  -H "Content-Type: application/json" \
  -d '{"user":"alice"}'
```

**Response:**
```json
{
  "key": "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2",
  "user": "alice",
  "created": "2024-01-15T10:30:00.000000+00:00",
  "key_prefix": "a1b2c3d4"
}
```

**⚠️ IMPORTANT**: Save the `key` value immediately. It will never be shown again.

### Step 2: Configure MCP Client

Add the API key to your MCP client configuration:

```json
{
  "mcpServers": {
    "gcm": {
      "url": "http://localhost:8002/sse",
      "headers": {
        "Authorization": "Bearer a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2"
      }
    }
  }
}
```

### Step 3: Test Connection

```bash
# Health check (no auth required)
curl http://localhost:8002/health

# SSE endpoint (auth required)
curl http://localhost:8002/sse \
  -H "Authorization: Bearer a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2"
```

---

## Admin Endpoints

Admin endpoints are **localhost-only** for security. They do not require API key authentication.

### Allowed IPs
- `127.0.0.1` (IPv4 localhost)
- `::1` (IPv6 localhost)
- `localhost` (hostname)
- `172.17.0.1` (Docker bridge - host access)

### Create API Key

**Endpoint**: `POST /admin/keys`

**Request:**
```bash
curl -X POST http://localhost:8002/admin/keys \
  -H "Content-Type: application/json" \
  -d '{"user":"bob"}'
```

**Response:**
```json
{
  "key": "<64-char-hex-string>",
  "user": "bob",
  "created": "2024-01-15T10:30:00.000000+00:00",
  "key_prefix": "x7y8z9a0"
}
```

### List API Keys

**Endpoint**: `GET /admin/keys`

**Request:**
```bash
curl http://localhost:8002/admin/keys
```

**Response:**
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

**Note**: Raw keys and hashes are never returned.

### Revoke API Key

**Endpoint**: `DELETE /admin/keys/{key_prefix}`

**Request:**
```bash
curl -X DELETE http://localhost:8002/admin/keys/a1b2c3d4
```

**Response:**
```json
{
  "status": "revoked",
  "key_prefix": "a1b2c3d4",
  "user": "alice"
}
```

---

## Platform-Specific Instructions

### Docker (Standalone)

**Generate key:**
```bash
# From host machine
docker exec -it gcm-mcp-server curl -X POST http://localhost:8002/admin/keys \
  -H "Content-Type: application/json" \
  -d '{"user":"alice"}'
```

**List keys:**
```bash
docker exec -it gcm-mcp-server curl http://localhost:8002/admin/keys
```

**Revoke key:**
```bash
docker exec -it gcm-mcp-server curl -X DELETE http://localhost:8002/admin/keys/a1b2c3d4
```

### Docker Compose

**Generate key:**
```bash
docker-compose exec gcm-mcp-server curl -X POST http://localhost:8002/admin/keys \
  -H "Content-Type: application/json" \
  -d '{"user":"alice"}'
```

**Alternative (from host if port is exposed):**
```bash
curl -X POST http://localhost:8002/admin/keys \
  -H "Content-Type: application/json" \
  -d '{"user":"alice"}'
```

### Kubernetes

**Port-forward to access admin endpoints:**
```bash
# Forward port 8002 to localhost
kubectl port-forward -n gcm-mcp deployment/gcm-mcp-server 8002:8002
```

**In another terminal, generate key:**
```bash
curl -X POST http://localhost:8002/admin/keys \
  -H "Content-Type: application/json" \
  -d '{"user":"alice"}'
```

**Alternative (exec into pod):**
```bash
kubectl exec -it -n gcm-mcp deployment/gcm-mcp-server -- \
  curl -X POST http://localhost:8002/admin/keys \
  -H "Content-Type: application/json" \
  -d '{"user":"alice"}'
```

### Bare Metal / Development

**Generate key:**
```bash
curl -X POST http://localhost:8002/admin/keys \
  -H "Content-Type: application/json" \
  -d '{"user":"alice"}'
```

---

## Key Management Best Practices

### Generation

✅ **DO:**
- Generate unique keys per user/client
- Use descriptive usernames for tracking
- Save keys immediately in secure storage
- Document key ownership in a registry

❌ **DON'T:**
- Share keys between users
- Store keys in plain text files
- Commit keys to version control
- Use generic usernames like "test" or "user"

### Storage

**Client-side storage options:**

| Platform | Recommended Storage |
|----------|-------------------|
| macOS | Keychain |
| Windows | DPAPI / Credential Manager |
| Linux | libsecret / gnome-keyring |
| CI/CD | Environment variables / Secrets manager |

**Server-side:**
- Keys stored as SHA-256 hashes in `/data/keys.json`
- File permissions: `0600` (owner read/write only)
- Persistent volume recommended for container deployments

### Rotation

**Recommended rotation schedule:**
- **Development**: Every 90 days
- **Production**: Every 30-60 days
- **After breach**: Immediately

**Rotation procedure:**
1. Generate new key for user
2. Update client configuration with new key
3. Test connection with new key
4. Revoke old key after grace period (e.g., 24 hours)

### Revocation

**Revoke immediately if:**
- Key is compromised or leaked
- User no longer needs access
- Client is decommissioned
- Security incident occurs

**Revocation is permanent** - generate a new key if access is needed again.

---

## Security Considerations

### Key Security

- **Entropy**: Keys use `secrets.token_hex(32)` for cryptographic randomness
- **Hashing**: SHA-256 with no salt (keys are already high-entropy)
- **Storage**: File permissions prevent unauthorized access
- **Transmission**: Use HTTPS in production (not HTTP)

### Admin Endpoint Security

- **Localhost-only**: Admin endpoints reject non-localhost requests
- **No authentication**: Relies on network-level access control
- **Docker bridge**: Allows host access via `172.17.0.1`

**⚠️ WARNING**: Ensure admin endpoints are not exposed via reverse proxy or ingress.

### Network Security

**Production recommendations:**
1. **Use HTTPS**: Terminate SSL at reverse proxy or load balancer
2. **Firewall rules**: Restrict access to known client IPs
3. **Rate limiting**: Implement at reverse proxy level
4. **Network policies**: Use Kubernetes NetworkPolicy to limit pod access

### Monitoring and Auditing

**Log events:**
- Failed authentication attempts (logged with client IP)
- Key generation (logged with username)
- Key revocation (logged with prefix and username)

**Monitor:**
- Unusual access patterns
- Failed authentication rate
- Key usage per user
- Admin endpoint access

---

## Troubleshooting

### 401 Unauthorized

**Symptom**: Client receives `{"error": "Unauthorized", "message": "Invalid or missing API key"}`

**Causes:**
1. Missing `Authorization` header
2. Incorrect header format (must be `Bearer <key>`)
3. Invalid or revoked key
4. Typo in key value

**Solutions:**
```bash
# Verify key format
curl http://localhost:8002/sse \
  -H "Authorization: Bearer <your-key>" \
  -v

# Check active keys
curl http://localhost:8002/admin/keys

# Generate new key if needed
curl -X POST http://localhost:8002/admin/keys \
  -H "Content-Type: application/json" \
  -d '{"user":"test"}'
```

### 403 Forbidden (Admin Endpoints)

**Symptom**: `{"error": "Forbidden", "message": "Admin endpoints are localhost only"}`

**Cause**: Request not from allowed IP

**Solutions:**
- Use `localhost` or `127.0.0.1` instead of server hostname
- For Docker: Use `docker exec` to run commands inside container
- For Kubernetes: Use `kubectl port-forward` or `kubectl exec`

### Key Not Working After Generation

**Checklist:**
1. ✅ Copied entire 64-character key (no truncation)
2. ✅ No extra spaces or newlines in key
3. ✅ Using `Bearer` prefix in Authorization header
4. ✅ Key not revoked (check with `GET /admin/keys`)
5. ✅ Server restarted after key generation (if needed)

### Key Store File Issues

**Symptom**: Server logs show key store errors

**Check:**
```bash
# Verify file exists and has correct permissions
ls -la /data/keys.json

# Should show: -rw------- (0600)
```

**Fix permissions:**
```bash
chmod 600 /data/keys.json
chown 1000:1000 /data/keys.json  # Container user
```

---

## Advanced Topics

### Key Store Structure

**File**: `/data/keys.json`

**Format:**
```json
{
  "keys": {
    "<sha256-hash>": {
      "user": "alice",
      "created": "2024-01-15T10:30:00.000000+00:00",
      "key_prefix": "a1b2c3d4"
    }
  }
}
```

**Notes:**
- Keys indexed by SHA-256 hash (64 hex chars)
- Raw keys never stored
- File created automatically on first key generation

### Programmatic Access

See [API Key Management Guide](docs/api-key-management.md) for:
- Automation scripts
- Batch key generation
- Integration with secret managers
- CI/CD pipeline examples

### Client Configuration

See [Client Configuration Guide](docs/client-configuration.md) for:
- IBM Bob setup
- Claude Desktop configuration
- Continue (VS Code) setup
- Generic MCP client examples

---

## FAQ

**Q: Can I use the same key for multiple clients?**
A: Technically yes, but not recommended. Generate unique keys per client for better tracking and security.

**Q: Do keys expire?**
A: No, keys do not expire automatically. Implement manual rotation policies.

**Q: Can I recover a lost key?**
A: No, keys are shown only once. Generate a new key if lost.

**Q: How many keys can I create?**
A: No hard limit, but keep the number manageable for tracking purposes.

**Q: Can I use API keys with STDIO mode?**
A: No, STDIO mode does not use API key authentication (process-level security).

**Q: What happens if I delete `/data/keys.json`?**
A: All keys are lost. Clients will need new keys. The file will be recreated on next key generation.

**Q: Can I edit `/data/keys.json` manually?**
A: Not recommended. Use admin endpoints for all key operations.

**Q: How do I backup keys?**
A: Backup `/data/keys.json` file. Restore it to recover all keys (hashes only - raw keys cannot be recovered).

---

## Related Documentation

- [API Key Management Guide](docs/api-key-management.md) - Detailed API reference and automation
- [Client Configuration Guide](docs/client-configuration.md) - MCP client setup examples
- [Main README](README.md) - Server overview and setup
- [Contributing Guide](CONTRIBUTING.md) - Development guidelines

---

## Support

For issues related to authentication:

1. Check this guide's troubleshooting section
2. Review server logs for error messages
3. Verify network connectivity and firewall rules
4. Open an issue on GitHub with details

**Security issues**: Report privately to maintainers, do not open public issues.