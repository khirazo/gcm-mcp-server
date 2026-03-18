#!/bin/bash
# This file includes AI-generated code - Review and modify as needed
set -e

# Color output for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== GCM MCP Server Startup ===${NC}"

# Load configuration from TOML file if it exists
if [ -f /config/config.toml ]; then
    echo -e "${GREEN}Loading configuration from /config/config.toml...${NC}"
    python /config-loader.py /config/config.toml
else
    echo -e "${YELLOW}Warning: /config/config.toml not found, using environment variables only${NC}"
fi

# Validate required environment variables
echo -e "${GREEN}Validating required environment variables...${NC}"

MISSING_VARS=()

if [ -z "${GCM_HOST}" ]; then
    MISSING_VARS+=("GCM_HOST")
fi

if [ -z "${GCM_USERNAME}" ]; then
    MISSING_VARS+=("GCM_USERNAME")
fi

if [ -z "${GCM_PASSWORD}" ]; then
    MISSING_VARS+=("GCM_PASSWORD")
fi

if [ -z "${GCM_CLIENT_SECRET}" ]; then
    MISSING_VARS+=("GCM_CLIENT_SECRET")
fi

if [ ${#MISSING_VARS[@]} -ne 0 ]; then
    echo -e "${RED}ERROR: Missing required environment variables:${NC}"
    for var in "${MISSING_VARS[@]}"; do
        echo -e "${RED}  - ${var}${NC}"
    done
    echo ""
    echo "Set them using:"
    echo "  - Docker: -e GCM_HOST=... -e GCM_USERNAME=... etc."
    echo "  - Docker Compose: environment section or .env file"
    echo "  - Kubernetes: Secret and ConfigMap"
    echo ""
    exit 1
fi

echo -e "${GREEN}✓ All required environment variables are set${NC}"

# Display configuration (without sensitive data)
echo -e "${GREEN}Configuration:${NC}"
echo "  GCM Host: ${GCM_HOST}"
echo "  GCM API Port: ${GCM_API_PORT:-31443}"
echo "  GCM Keycloak Port: ${GCM_KEYCLOAK_PORT:-30443}"
echo "  MCP Transport: ${MCP_TRANSPORT:-stdio}"
echo "  Log Level: ${GCM_LOG_LEVEL:-INFO}"
echo ""

# Start MCP Server based on transport mode
# Default to stdio mode (for laptop deployment with IBM Bob)
TRANSPORT="${1:-${MCP_TRANSPORT:-stdio}}"

# Ensure data directory exists for SSE mode (API key storage)
if [ "${TRANSPORT}" = "sse" ]; then
    if [ ! -d /data ]; then
        echo -e "${YELLOW}Creating /data directory for API key storage...${NC}"
        mkdir -p /data
    fi
fi

echo -e "${GREEN}Starting GCM MCP Server (${TRANSPORT} mode)...${NC}"
echo ""

if [ "${TRANSPORT}" = "stdio" ]; then
    exec python -m src
elif [ "${TRANSPORT}" = "sse" ]; then
    exec python -m src --transport sse --host "${MCP_HOST:-0.0.0.0}" --port "${MCP_PORT:-8002}"
else
    # Custom command
    exec "$@"
fi

# Made with Bob
