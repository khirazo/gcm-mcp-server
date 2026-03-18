#!/bin/bash
# MCP Server Test Script
# Tests stdio mode by sending JSON-RPC requests in sequence to a single container instance

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== MCP Server Test Script ===${NC}"
echo ""
echo -e "${YELLOW}Testing MCP protocol with sequential requests in a single session${NC}"
echo ""

# Create a temporary file for requests
REQUESTS_FILE=$(mktemp)

# Write all requests to the file (one per line)
cat > "$REQUESTS_FILE" << 'EOF'
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test-client","version":"1.0.0"}}}
{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}
{"jsonrpc":"2.0","id":3,"method":"prompts/list","params":{}}
{"jsonrpc":"2.0","id":4,"method":"resources/list","params":{}}
EOF

echo -e "${GREEN}Sending requests:${NC}"
echo -e "${BLUE}1. initialize${NC}"
echo -e "${BLUE}2. tools/list${NC}"
echo -e "${BLUE}3. prompts/list${NC}"
echo -e "${BLUE}4. resources/list${NC}"
echo ""

echo -e "${YELLOW}Starting MCP server and sending requests...${NC}"
echo ""

# Send all requests to the server and capture output
OUTPUT=$(cat "$REQUESTS_FILE" | docker compose run --rm -T gcm-mcp-server 2>&1)

# Clean up temp file
rm "$REQUESTS_FILE"

# Extract JSON responses (lines starting with {)
RESPONSES=$(echo "$OUTPUT" | grep -E '^\{')

# Parse and display each response
echo -e "${GREEN}=== Test Results ===${NC}"
echo ""

# Response 1: Initialize
echo -e "${BLUE}Test 1: Initialize${NC}"
echo "$RESPONSES" | sed -n '1p' | jq '.'
echo ""

# Response 2: Tools List
echo -e "${BLUE}Test 2: List Tools${NC}"
TOOLS_RESPONSE=$(echo "$RESPONSES" | sed -n '2p')
if echo "$TOOLS_RESPONSE" | jq -e '.result.tools' > /dev/null 2>&1; then
    echo "$TOOLS_RESPONSE" | jq '.result.tools[] | {name: .name, description: .description}'
else
    echo "$TOOLS_RESPONSE" | jq '.'
fi
echo ""

# Response 3: Prompts List
echo -e "${BLUE}Test 3: List Prompts${NC}"
echo "$RESPONSES" | sed -n '3p' | jq '.'
echo ""

# Response 4: Resources List
echo -e "${BLUE}Test 4: List Resources${NC}"
echo "$RESPONSES" | sed -n '4p' | jq '.'
echo ""

echo -e "${GREEN}=== All tests completed ===${NC}"
echo ""
echo -e "${BLUE}Summary:${NC}"
echo "- Initialize: $(echo "$RESPONSES" | sed -n '1p' | jq -r 'if .result then "✓ Success" else "✗ Failed" end')"
echo "- Tools List: $(echo "$RESPONSES" | sed -n '2p' | jq -r 'if .result.tools then "✓ Success (" + (.result.tools | length | tostring) + " tools)" else "✗ Failed" end')"
echo "- Prompts List: $(echo "$RESPONSES" | sed -n '3p' | jq -r 'if .result then "✓ Success" else "✗ Failed" end')"
echo "- Resources List: $(echo "$RESPONSES" | sed -n '4p' | jq -r 'if .result then "✓ Success" else "✗ Failed" end')"

# Made with Bob
