#!/bin/bash

# Check if the VPN container is running
# This script should be run on the host before starting the devcontainer

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Checking VPN container status...${NC}"

if docker ps | grep -q "vpn"; then
    echo -e "${GREEN}VPN container is running!${NC}"
    echo "The devcontainer will connect to the VPN container's network."
else
    echo -e "${RED}WARNING: VPN container is not running!${NC}"
    echo "The devcontainer is configured to use the VPN container's network,"
    echo "but the container 'vpn' doesn't appear to be running."
    echo ""
    echo "You have two options:"
    echo "1. Start the VPN container before continuing"
    echo "2. Edit .devcontainer/devcontainer.json and remove the 'runArgs' section"
    echo ""
    echo "To continue with the VPN, start the VPN container and try again."
    exit 1
fi