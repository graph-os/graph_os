#!/bin/bash

# Helper script to check Claude Code authentication status and authenticate if needed

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Checking Claude Code authentication status...${NC}"

# Check if already authenticated
if [ -f "/home/coder/.config/anthropic/claude-code.json" ]; then
    echo -e "${GREEN}Claude Code authentication token found!${NC}"
    echo "Authentication should be persisted across container restarts."
    echo ""
    echo "If you need to re-authenticate, run:"
    echo "  claude login"
else
    echo "No authentication token found."
    echo "Authenticating Claude Code..."
    echo ""
    claude login
fi