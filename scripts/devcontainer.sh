#!/bin/bash

# Script to start and attach to the GraphOS devcontainer without VS Code
# Usage: ./scripts/devcontainer.sh [command]
# Special commands:
#   setup - Run the setup script inside the container
#   If no command is provided, it starts an interactive shell

set -e

# Colors for output
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Container name
CONTAINER_NAME="graphos-devcontainer"

# Project root directory (parent of this script)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
  echo -e "${RED}Docker is not running. Please start Docker and try again.${NC}"
  exit 1
fi

# Check if VPN container is running
if docker ps | grep -q "vpn"; then
  echo -e "${GREEN}VPN container is running! Will use VPN network.${NC}"
  NETWORK_ARGS="--network=container:vpn"
else
  echo -e "${YELLOW}VPN container is not running. Will use standard network.${NC}"
  NETWORK_ARGS="-p 4000:4000 -p 4001:4001"
fi

# Check if container already exists
if docker ps -a | grep -q "${CONTAINER_NAME}"; then
  echo -e "${YELLOW}Container ${CONTAINER_NAME} already exists.${NC}"
  
  # Check if the container is running
  if docker ps | grep -q "${CONTAINER_NAME}"; then
    echo -e "${GREEN}Container is running. Connecting...${NC}"
  else
    echo -e "${YELLOW}Container is stopped. Starting...${NC}"
    docker start "${CONTAINER_NAME}"
  fi
else
  echo -e "${YELLOW}Creating new container...${NC}"
  
  # Build image if needed
  if ! docker images | grep -q "graphos-dev-coder"; then
    echo -e "${YELLOW}Building devcontainer image...${NC}"
    cd "${PROJECT_ROOT}" && docker build -t graphos-dev-coder .devcontainer
  fi
  
  # Create and start the container
  echo -e "${GREEN}Starting new devcontainer...${NC}"
  docker run -d \
    --name "${CONTAINER_NAME}" \
    ${NETWORK_ARGS} \
    -v "${PROJECT_ROOT}:/workspace" \
    -v "${HOME}/.env:/home/coder/.env:ro" \
    -v "${HOME}/.config/anthropic:/home/coder/.config/anthropic" \
    -v "${HOME}/.cache/anthropic:/home/coder/.cache/anthropic" \
    --env TERM=xterm-256color \
    graphos-dev-coder \
    sleep infinity
    
  # Set flag to indicate container was just created
  CONTAINER_JUST_CREATED="true"
fi

# Run setup script if container was just created
if [ "$CONTAINER_JUST_CREATED" = "true" ]; then
  echo -e "${YELLOW}Running setup script...${NC}"
  docker exec "${CONTAINER_NAME}" bash -c "/workspace/.devcontainer/setup-container.sh"
fi

# Execute the command or start a shell
if [ $# -eq 0 ]; then
  echo -e "${GREEN}Starting interactive shell...${NC}"
  docker exec -it "${CONTAINER_NAME}" bash
elif [ "$1" = "setup" ]; then
  echo -e "${GREEN}Running setup script...${NC}"
  docker exec -it "${CONTAINER_NAME}" bash -c "/workspace/.devcontainer/setup-container.sh"
else
  echo -e "${GREEN}Running command: $@${NC}"
  docker exec -it "${CONTAINER_NAME}" $@
fi