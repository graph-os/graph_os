#!/bin/bash

# Script to start MCP server in the devcontainer
# Usage: ./scripts/mcp.sh [mode]
# Available modes: server, sse, stdio, debug, inspect (default: server)

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Set default mode
MODE=${1:-server}

# Validate mode
case "$MODE" in
  server|sse|stdio|debug|inspect)
    echo "Starting MCP server in $MODE mode..."
    ;;
  *)
    echo "Unknown mode: $MODE"
    echo "Available modes: server, sse, stdio, debug, inspect"
    exit 1
    ;;
esac

# Run MCP server in the devcontainer
"${SCRIPT_DIR}/devcontainer.sh" mix mcp.$MODE