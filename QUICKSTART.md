# Quick Start - Laptop Deployment with IBM Bob

This guide helps you set up GCM MCP Server on your laptop for use with IBM Bob MCP client via stdio connection.

## 📋 Prerequisites

- **Docker Desktop** (or Docker Engine + Docker Compose)
- **IBM Bob** MCP client installed
- **GCM credentials** (username, password, client secret)
- **Git** (for cloning the repository)

## 🚀 Setup (3 Steps)

### Step 1: Clone and Configure

```bash
# Clone the repository
git clone https://github.com/khirazo/gcm-mcp-server.git
cd gcm-mcp-server

# Copy environment template
cp .env.example .env

# Edit .env with your GCM credentials
# Use your preferred text editor (nano, vim, notepad, etc.)
nano .env
```

**Required values in `.env`:**
```bash
GCM_HOST=your-gcm-server.example.com
GCM_USERNAME=your-username
GCM_PASSWORD=your-password
GCM_CLIENT_SECRET=your-client-secret
```

**Optional: Edit `config/config.toml`** for non-sensitive settings (ports, log level, etc.)

### Step 2: Build Container

```bash
# Build the Docker image
docker compose build

# Verify the build
docker images | grep gcm-mcp-server
```

Expected output:
```
gcm-mcp-server:latest   f5e33fb2522e        241MB             0B   U
gcm-mcp-server:stdio    979e8bcab458        241MB             0B
```

### Step 3: Configure IBM Bob

Add the GCM MCP server to IBM Bob's configuration file.

**Location of Bob's config file:**

- **Windows**: `%USERPROFILE%\.bob\settings\mcp_settings.json`
- **macOS**: `~/.bob/settings/mcp_settings.json`
- **Linux**: `~/.bob/settings/mcp_settings.json`

**Configuration examples by platform:**

#### Option 1: Docker Desktop (Windows/macOS/Linux)

```json
{
  "mcpServers": {
    "gcm-mcp-server": {
      "command": "docker",
      "args": [
        "compose",
        "run",
        "--rm",
        "gcm-mcp-server"
      ],
      "cwd": "/absolute/path/to/gcm-mcp-server",
      "env": {}
    }
  }
}
```

**Example paths:**
- **Windows**: `C:\\Users\\YourName\\Projects\\gcm-mcp-server`
- **macOS**: `/Users/yourname/projects/gcm-mcp-server`
- **Linux**: `/home/yourname/projects/gcm-mcp-server`

#### Option 2: WSL2 Docker (Windows with WSL2)

If you're using Docker installed in WSL2 (not Docker Desktop), use this configuration:

```json
{
  "mcpServers": {
    "gcm-mcp-server": {
      "command": "wsl",
      "args": [
        "-d",
        "Ubuntu",
        "bash",
        "-c",
        "cd /path/to/gcm-mcp-server && docker compose run --rm gcm-mcp-server"
      ],
      "env": {}
    }
  }
}
```

**Important notes for WSL2:**
- Replace `Ubuntu` with your WSL distribution name (check with `wsl -l -v`)
- Use **Linux-style path** in WSL: `/home/yourname/projects/gcm-mcp-server`
- If repository is on Windows filesystem, use: `/mnt/c/Users/YourName/Projects/gcm-mcp-server`

**To find your WSL distribution name:**
```powershell
# Run in PowerShell or Command Prompt
wsl -l -v
```

Example output:
```
  NAME      STATE           VERSION
* Ubuntu    Running         2
```

**Alternative WSL2 configuration (if repository is in Windows filesystem):**

```json
{
  "mcpServers": {
    "gcm-mcp-server": {
      "command": "wsl",
      "args": [
        "-d",
        "Ubuntu",
        "bash",
        "-c",
        "cd /mnt/c/Users/YourName/Projects/gcm-mcp-server && docker compose run --rm gcm-mcp-server"
      ],
      "env": {}
    }
  }
}
```

**Performance tip:** For better performance with WSL2, clone the repository inside WSL filesystem (`/home/yourname/`) rather than Windows filesystem (`/mnt/c/`).

## ✅ Verification

### Test the Container

```bash
# Test that the container starts correctly
docker compose run --rm gcm-mcp-server

# You should see startup logs like:
=== GCM MCP Server Startup ===
Loading configuration from /config/config.toml...
Configuration loaded from /config/config.toml
✓ All required environment variables are set
Configuration:
  GCM Host: 10.0.0.111
  GCM API Port: 31443
  GCM Keycloak Port: 30443
  MCP Transport: stdio
  Log Level: INFO

Starting GCM MCP Server (stdio mode)...
```

Press `Ctrl+C` to stop the test.

### Test MCP Protocol (Optional)

Test the MCP server's JSON-RPC interface using the provided test scripts:

**Option 1: Automated Test (Recommended)**

```bash
# Run automated tests
bash scripts/test-mcp.sh

# This will test:
# - Initialize connection
# - List tools
# - List prompts
# - List resources
```

**Option 2: Manual Test (Interactive)**

Start the container and paste JSON-RPC requests directly into the prompt:

```bash
# Start the MCP server
docker compose run --rm gcm-mcp-server
```

Then paste these requests one by one (press Enter after each):

**1. Initialize the session:**
```json
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}
```

**2. List available tools:**
```json
{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}
```

**3. List available prompts:**
```json
{"jsonrpc":"2.0","id":3,"method":"prompts/list","params":{}}
```

**4. List available resources:**
```json
{"jsonrpc":"2.0","id":4,"method":"resources/list","params":{}}
```

**Expected responses:**
- Initialize: Returns server info and capabilities
- Tools list: Returns 3 tools (gcm_auth, gcm_api, gcm_discover)
- Prompts list: Returns available prompt templates
- Resources list: Returns available resources

Press `Ctrl+C` to exit when done.

**Note for Windows users:**
- Use Git Bash or WSL to run the test scripts
- PowerShell may have issues with JSON formatting

### Test with IBM Bob

1. **Restart IBM Bob** (or reload the VS Code window)
2. **Open Bob's chat interface**
3. **Try a GCM command**, for example:
   ```
   List all available GCM services
   ```

Bob should now be able to use the GCM MCP tools:
- `gcm_auth` - Authenticate with GCM
- `gcm_api` - Call GCM APIs
- `gcm_discover` - Discover available GCM services

## 🔧 Troubleshooting

### Container won't start

**Check logs:**
```bash
docker compose run --rm gcm-mcp-server
```

**Common issues:**
1. **Missing credentials**: Verify `.env` file has all required values
2. **Invalid credentials**: Check username/password/client secret
3. **Network issues**: Ensure you can reach the GCM server from your laptop
4. **Permission denied on /data**: This error should not occur in stdio mode (fixed in latest version). If you see it:
   ```bash
   # Rebuild the container to get the latest entrypoint.sh
   docker compose build --no-cache
   ```

### IBM Bob can't connect

**Verify configuration:**
1. Check that `cwd` path in Bob's config is correct (absolute path)
2. Ensure Docker is running
3. Restart VS Code after changing Bob's configuration

**Test Docker Compose manually:**
```bash
cd /path/to/gcm-mcp-server
docker compose run --rm gcm-mcp-server
```

### Permission errors

**On Linux/macOS:**
```bash
# Ensure scripts are executable
chmod +x scripts/*.sh scripts/*.py
```

**Docker permission issues:**
```bash
# Add your user to docker group (Linux)
sudo usermod -aG docker $USER
# Log out and back in for changes to take effect
```

### WSL2-specific issues

**"docker: command not found" in WSL:**
```bash
# Install Docker in WSL2 (if not using Docker Desktop)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add your user to docker group
sudo usermod -aG docker $USER

# Start Docker service
sudo service docker start
```

**Path conversion issues:**
```bash
# If you see "no such file or directory" errors:
# 1. Verify the path exists in WSL
cd /mnt/c/Users/YourName/Projects/gcm-mcp-server  # Windows path
# OR
cd /home/yourname/projects/gcm-mcp-server  # WSL path

# 2. Check if docker compose works
docker compose run --rm gcm-mcp-server
```

**Line ending issues (CRLF vs LF):**
```bash
# If you see "bad interpreter" or syntax errors:
# Convert line endings to Unix format
sudo apt-get install dos2unix
find . -type f -name "*.sh" -exec dos2unix {} \;
find . -type f -name "*.py" -exec dos2unix {} \;
```

**Performance issues with /mnt/c/ paths:**
- **Problem**: Slow file access when repository is on Windows filesystem
- **Solution**: Clone repository inside WSL filesystem for better performance
  ```bash
  # Inside WSL
  cd ~
  git clone https://github.com/your-org/gcm-mcp-server.git
  cd gcm-mcp-server
  ```

## 📚 Next Steps

- **[README.md](README.md)** - Full documentation and architecture
- **[AUTHENTICATION.md](AUTHENTICATION.md)** - Authentication details
- **[CHANGELOG.md](CHANGELOG.md)** - Version history and changes

## 🆘 Support

For issues:
1. Check the troubleshooting section above
2. Review Docker logs: `docker compose logs`
3. Open an issue on GitHub with:
   - Your OS and Docker version
   - Error messages from logs
   - Steps to reproduce

## 💡 Tips

### Update to Latest Version

```bash
# Pull latest changes
git pull origin main

# Rebuild container
docker compose build

# Restart IBM Bob
```

### View Logs

```bash
# Run with logs visible
docker compose run --rm gcm-mcp-server

# Or check logs from a running container
docker compose logs -f gcm-mcp-server
```

### Change Log Level

Edit `.env` file:
```bash
GCM_LOG_LEVEL=DEBUG  # For detailed logs
GCM_LOG_LEVEL=INFO   # Default
GCM_LOG_LEVEL=ERROR  # Minimal logs
```

Then rebuild:
```bash
docker compose build
```

---

**Ready to use GCM with IBM Bob!** 🎉