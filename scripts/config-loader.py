#!/usr/bin/env python3
# This file includes AI-generated code - Review and modify as needed
"""
TOML Configuration Loader for GCM MCP Server

Loads configuration from TOML file and exports as environment variables.
Environment variables take precedence over TOML values.
"""

import sys
import os

try:
    import tomllib
except ImportError:
    import tomli as tomllib


def load_toml_to_env(toml_path: str) -> None:
    """
    Load TOML configuration file and set environment variables.
    
    Existing environment variables are not overwritten (they have priority).
    
    Args:
        toml_path: Path to the TOML configuration file
    """
    if not os.path.exists(toml_path):
        print(f"Warning: Configuration file not found: {toml_path}", file=sys.stderr)
        return
    
    try:
        with open(toml_path, 'rb') as f:
            config = tomllib.load(f)
    except Exception as e:
        print(f"Error loading TOML configuration: {e}", file=sys.stderr)
        sys.exit(1)
    
    # GCM Configuration
    if 'gcm' in config:
        gcm = config['gcm']
        os.environ.setdefault('GCM_HOST', str(gcm.get('host', '')))
        os.environ.setdefault('GCM_API_PORT', str(gcm.get('api_port', 31443)))
        os.environ.setdefault('GCM_KEYCLOAK_PORT', str(gcm.get('keycloak_port', 30443)))
        os.environ.setdefault('GCM_VERIFY_SSL', str(gcm.get('verify_ssl', False)).lower())
        os.environ.setdefault('GCM_REQUEST_TIMEOUT', str(gcm.get('request_timeout', 30)))
        
        # GCM Authentication
        if 'auth' in gcm:
            auth = gcm['auth']
            os.environ.setdefault('GCM_USERNAME', str(auth.get('username', '')))
            os.environ.setdefault('GCM_PASSWORD', str(auth.get('password', '')))
            os.environ.setdefault('GCM_CLIENT_ID', str(auth.get('client_id', 'gcmclient')))
            os.environ.setdefault('GCM_CLIENT_SECRET', str(auth.get('client_secret', '')))
            os.environ.setdefault('GCM_AUTH_MODE', str(auth.get('auth_mode', 'auto')))
    
    # MCP Server Configuration
    if 'mcp' in config:
        mcp = config['mcp']
        # Default to stdio mode (for laptop deployment with IBM Bob)
        os.environ.setdefault('MCP_TRANSPORT', str(mcp.get('transport', 'stdio')))
        os.environ.setdefault('MCP_HOST', str(mcp.get('host', '0.0.0.0')))
        os.environ.setdefault('MCP_PORT', str(mcp.get('port', 8002)))
        os.environ.setdefault('GCM_MCP_KEY_STORE_PATH', str(mcp.get('key_store_path', '/data/keys.json')))
        os.environ.setdefault('GCM_LOG_LEVEL', str(mcp.get('log_level', 'INFO')))
        
        # MCP Security
        if 'security' in mcp:
            security = mcp['security']
            os.environ.setdefault('MCP_ENABLE_API_KEY_AUTH', str(security.get('enable_api_key_auth', True)).lower())
    
    print(f"Configuration loaded from {toml_path}", file=sys.stderr)


def main():
    """Main entry point for the configuration loader."""
    if len(sys.argv) < 2:
        print("Usage: config-loader.py <config.toml>", file=sys.stderr)
        sys.exit(1)
    
    toml_path = sys.argv[1]
    load_toml_to_env(toml_path)


if __name__ == '__main__':
    main()

# Made with Bob
