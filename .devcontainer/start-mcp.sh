#!/bin/bash

# Script to start MCP server in devcontainer
echo "Starting MCP server..."

# Choose the MCP server mode
case "$1" in
  "sse")
    mix mcp.sse
    ;;
  "stdio")
    mix mcp.stdio
    ;;
  "debug")
    mix mcp.debug
    ;;
  "inspect")
    mix mcp.inspect
    ;;
  *)
    # Default to standard server
    mix mcp.server
    ;;
esac