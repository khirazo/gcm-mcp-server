# MCP Client Configuration Guide

> ⚠️ **Deprecated — Not required for GCM 2.0.2 and later**
>
> GCM 2.0.2+ includes a built-in MCP server. This relay server and its API key management are only needed for GCM versions older than 2.0.2.
>
> **If you are on GCM 2.0.2 or later, see [gcm-api-samples/mcp_bob](https://github.com/IBM/gcm-api-samples/tree/main/mcp_bob) to connect Bob IDE directly to GCM.**

This guide provides configuration examples for connecting various MCP clients to the GCM MCP Server using API key authentication.

## Table of Contents

- [IBM Bob](#ibm-bob) ✅ Verified
- [Claude Desktop](#claude-desktop) ⚠️ Example
- [Continue (VS Code)](#continue-vs-code) ⚠️ Example
- [Cline (VS Code)](#cline-vs-code) ⚠️ Example
- [Generic MCP Client](#generic-mcp-client)
- [Troubleshooting](#troubleshooting)

---

## Important Notes

### Configuration Status

| Client | Status | Notes |
|--------|--------|-------|
| **IBM Bob** | ✅ Verified | Production-tested configuration |
| **Claude Desktop** | ⚠️ Example | Configuration pattern not verified in production |
| **Continue** | ⚠️ Example | Configuration pattern not verified in production |
| **Cline** | ⚠️ Example | Configuration pattern not verified in production |

⚠️ **Disclaimer**: Configurations marked as "Example" are provided as reference patterns based on MCP protocol specifications. They have not been tested in production environments. Please verify and adjust according to your specific client version and requirements.

### Prerequisites

Before configuring any client:

1. **Generate API Key**: Follow the [Authentication Guide](../AUTHENTICATION.md#quick-start)
2. **Server Running**: Ensure MCP server is running in SSE mode
3. **Network Access**: Verify client can reach server endpoint
4. **API Key Saved**: Store the API key securely

---

## IBM Bob

**Status**: ✅ Verified and production-tested

IBM Bob is an AI-powered coding assistant that supports MCP protocol for tool integration.

### Configuration

**Location**: Bob settings or configuration file (platform-specific)

**Format**:
```json
{
  "mcpServers": {
    "gcm": {
      "command": "node",
      "args": [
        "/path/to/mcp-client-sse.js",
        "http://your-gcm-mcp-server:8002/sse"
      ],
      "env": {
        "MCP_API_KEY": "your-api-key-here"
      }
    }
  }
}
```

**Alternative (Direct SSE Connection)**:
```json
{
  "mcpServers": {
    "gcm": {
      "url": "http://your-gcm-mcp-server:8002/sse",
      "transport": "sse",
      "headers": {
        "Authorization": "Bearer your-api-key-here"
      }
    }
  }
}
```

### Environment Variables

If Bob supports environment variable substitution:

```json
{
  "mcpServers": {
    "gcm": {
      "url": "http://your-gcm-mcp-server:8002/sse",
      "transport": "sse",
      "headers": {
        "Authorization": "Bearer ${GCM_MCP_API_KEY}"
      }
    }
  }
}
```

Then set the environment variable:
```bash
# Linux/macOS
export GCM_MCP_API_KEY="your-api-key-here"

# Windows (PowerShell)
$env:GCM_MCP_API_KEY="your-api-key-here"

# Windows (CMD)
set GCM_MCP_API_KEY=your-api-key-here
```

### Docker Deployment

If Bob runs in a container:

```yaml
# docker-compose.yml
services:
  bob:
    image: ibm/bob:latest
    environment:
      - GCM_MCP_API_KEY=${GCM_MCP_API_KEY}
    volumes:
      - ./bob-config.json:/config/mcp-servers.json:ro
```

### Verification

Test the connection:

1. Open Bob
2. Try using a GCM tool (e.g., "List GCM services")
3. Check Bob logs for connection status
4. Verify in MCP server logs: `docker logs gcm-mcp-server`

**Expected behavior**:
- Bob successfully connects to MCP server
- GCM tools appear in Bob's tool list
- Tool calls execute without authentication errors

---

## Claude Desktop

**Status**: ⚠️ Example configuration (not verified in production)

Claude Desktop is Anthropic's desktop application with MCP support.

### Configuration

**Location**: 
- macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`
- Windows: `%APPDATA%\Claude\claude_desktop_config.json`
- Linux: `~/.config/Claude/claude_desktop_config.json`

**Format**:
```json
{
  "mcpServers": {
    "gcm": {
      "command": "node",
      "args": [
        "/path/to/mcp-client-sse/index.js",
        "--url",
        "http://localhost:8002/sse",
        "--header",
        "Authorization: Bearer your-api-key-here"
      ]
    }
  }
}
```

**Alternative (if Claude supports direct SSE)**:
```json
{
  "mcpServers": {
    "gcm": {
      "url": "http://localhost:8002/sse",
      "headers": {
        "Authorization": "Bearer your-api-key-here"
      }
    }
  }
}
```

### Security Note

⚠️ **Warning**: Storing API keys in plain text configuration files is not recommended for production. Consider:

1. Using environment variables
2. Implementing a secrets manager
3. Using OS-level credential storage

### Verification

1. Restart Claude Desktop
2. Check Claude's settings for available MCP servers
3. Try using a GCM tool in conversation
4. Check logs: `~/Library/Logs/Claude/` (macOS)

---

## Continue (VS Code)

**Status**: ⚠️ Example configuration (not verified in production)

Continue is an AI coding assistant extension for VS Code with MCP support.

### Configuration

**Location**: `.continue/config.json` in your workspace or home directory

**Format**:
```json
{
  "mcpServers": [
    {
      "name": "gcm",
      "transport": "sse",
      "url": "http://localhost:8002/sse",
      "headers": {
        "Authorization": "Bearer your-api-key-here"
      }
    }
  ]
}
```

**Alternative (STDIO mode - if Continue spawns the server)**:
```json
{
  "mcpServers": [
    {
      "name": "gcm",
      "transport": "stdio",
      "command": "docker",
      "args": [
        "exec",
        "-i",
        "gcm-mcp-server",
        "python",
        "-m",
        "src",
        "--transport",
        "stdio"
      ]
    }
  ]
}
```

### VS Code Settings

Add to `.vscode/settings.json`:

```json
{
  "continue.mcpServers": [
    {
      "name": "gcm",
      "url": "http://localhost:8002/sse",
      "headers": {
        "Authorization": "Bearer ${env:GCM_MCP_API_KEY}"
      }
    }
  ]
}
```

### Environment Variables

Set in VS Code terminal or launch configuration:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Continue with GCM",
      "type": "extensionHost",
      "request": "launch",
      "env": {
        "GCM_MCP_API_KEY": "your-api-key-here"
      }
    }
  ]
}
```

### Verification

1. Reload VS Code window
2. Open Continue panel
3. Check for GCM tools in available tools list
4. Try executing a GCM tool

---

## Cline (VS Code)

**Status**: ⚠️ Example configuration (not verified in production)

Cline is another AI coding assistant for VS Code with MCP capabilities.

### Configuration

**Location**: Cline extension settings or `.cline/config.json`

**Format**:
```json
{
  "mcp": {
    "servers": {
      "gcm": {
        "url": "http://localhost:8002/sse",
        "transport": "sse",
        "auth": {
          "type": "bearer",
          "token": "your-api-key-here"
        }
      }
    }
  }
}
```

**Alternative (Environment Variable)**:
```json
{
  "mcp": {
    "servers": {
      "gcm": {
        "url": "http://localhost:8002/sse",
        "transport": "sse",
        "auth": {
          "type": "bearer",
          "token": "${GCM_MCP_API_KEY}"
        }
      }
    }
  }
}
```

### VS Code User Settings

Add to VS Code settings (`Ctrl+,` or `Cmd+,`):

```json
{
  "cline.mcpServers": {
    "gcm": {
      "url": "http://localhost:8002/sse",
      "headers": {
        "Authorization": "Bearer your-api-key-here"
      }
    }
  }
}
```

### Verification

1. Restart VS Code or reload Cline extension
2. Open Cline panel
3. Check connection status
4. Test GCM tool execution

---

## Generic MCP Client

For any MCP-compatible client, use these patterns:

### SSE Transport (HTTP)

**Minimum required configuration**:
```json
{
  "url": "http://localhost:8002/sse",
  "transport": "sse",
  "headers": {
    "Authorization": "Bearer <your-api-key>"
  }
}
```

**With additional options**:
```json
{
  "name": "gcm-mcp",
  "url": "http://localhost:8002/sse",
  "transport": "sse",
  "headers": {
    "Authorization": "Bearer <your-api-key>",
    "User-Agent": "MyMCPClient/1.0"
  },
  "timeout": 30000,
  "retries": 3
}
```

### STDIO Transport (Local)

**For local process communication** (no API key needed):

```json
{
  "name": "gcm-mcp",
  "transport": "stdio",
  "command": "docker",
  "args": [
    "exec",
    "-i",
    "gcm-mcp-server",
    "python",
    "-m",
    "src",
    "--transport",
    "stdio"
  ]
}
```

### Connection Test

**Using curl**:
```bash
# Test SSE endpoint
curl -N http://localhost:8002/sse \
  -H "Authorization: Bearer your-api-key-here" \
  -H "Accept: text/event-stream"

# Expected: SSE stream with server events
```

**Using Python**:
```python
import requests

url = "http://localhost:8002/sse"
headers = {
    "Authorization": "Bearer your-api-key-here",
    "Accept": "text/event-stream"
}

response = requests.get(url, headers=headers, stream=True)
print(f"Status: {response.status_code}")

for line in response.iter_lines():
    if line:
        print(line.decode('utf-8'))
```

---

## Troubleshooting

### Connection Refused

**Symptom**: Client cannot connect to MCP server

**Solutions**:
1. Verify server is running: `curl http://localhost:8002/health`
2. Check port mapping: `docker ps` or `docker-compose ps`
3. Verify firewall rules
4. Check network connectivity

### 401 Unauthorized

**Symptom**: `{"error": "Unauthorized", "message": "Invalid or missing API key"}`

**Solutions**:
1. Verify API key is correct (64 hex characters)
2. Check header format: `Authorization: Bearer <key>`
3. Ensure no extra spaces or newlines in key
4. Verify key is not revoked: `curl http://localhost:8002/admin/keys`

### Tools Not Appearing

**Symptom**: Client connects but GCM tools don't appear

**Solutions**:
1. Check client logs for MCP protocol errors
2. Verify server logs: `docker logs gcm-mcp-server`
3. Test tool listing: See [Testing Tools](#testing-tools)
4. Restart client application

### SSL/TLS Errors

**Symptom**: Certificate verification errors

**Solutions**:
1. Use HTTP for local development
2. For production, ensure valid SSL certificate
3. Configure client to trust self-signed certificates (not recommended)

### Testing Tools

**List available tools**:
```bash
# Using MCP protocol (requires MCP client library)
# This is a conceptual example - actual implementation varies by client

curl -X POST http://localhost:8002/messages/ \
  -H "Authorization: Bearer your-api-key-here" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/list",
    "params": {}
  }'
```

**Expected response**:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "tools": [
      {
        "name": "gcm_auth",
        "description": "Authenticate to GCM and get access token"
      },
      {
        "name": "gcm_api",
        "description": "Make authenticated API calls to GCM services"
      },
      {
        "name": "gcm_discover",
        "description": "Discover available GCM services"
      }
    ]
  }
}
```

---

## Security Best Practices

### API Key Storage

✅ **DO**:
- Use environment variables
- Use OS credential managers (Keychain, DPAPI, libsecret)
- Use secrets management tools (Vault, AWS Secrets Manager)
- Encrypt configuration files

❌ **DON'T**:
- Commit API keys to version control
- Share API keys between users
- Store keys in plain text files
- Log API keys

### Network Security

**For production deployments**:

1. **Use HTTPS**: Always use TLS for remote connections
2. **Firewall rules**: Restrict access to known client IPs
3. **VPN**: Use VPN for remote access
4. **Network policies**: Implement Kubernetes NetworkPolicy

### Client Configuration

**Secure configuration example**:

```json
{
  "mcpServers": {
    "gcm": {
      "url": "https://gcm-mcp.example.com/sse",
      "headers": {
        "Authorization": "Bearer ${GCM_MCP_API_KEY}"
      },
      "tls": {
        "verify": true,
        "ca": "/path/to/ca-cert.pem"
      }
    }
  }
}
```

---

## Platform-Specific Notes

### macOS

- Configuration files typically in `~/Library/Application Support/`
- Use Keychain for API key storage
- May need to allow network access in Security & Privacy settings

### Windows

- Configuration files typically in `%APPDATA%`
- Use Credential Manager for API key storage
- May need to allow through Windows Firewall

### Linux

- Configuration files typically in `~/.config/`
- Use libsecret or gnome-keyring for API key storage
- Check SELinux/AppArmor policies if connection fails

---

## Related Documentation

- [Authentication Guide](../AUTHENTICATION.md) - Main authentication documentation
- [API Key Management](api-key-management.md) - Detailed key management guide
- [Server README](../README.md) - Server setup and configuration

---

## Support

For client configuration issues:

1. Check client-specific documentation
2. Verify API key is valid
3. Test connection with curl
4. Check server logs for errors
5. Review this guide's troubleshooting section

**Client-specific issues**: Consult the client's official documentation or support channels.

**Server issues**: See [Authentication Guide](../AUTHENTICATION.md) troubleshooting section.