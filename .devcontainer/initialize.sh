#!/bin/bash

# Simple initialization script for VPN check
# Check if the VPN container is running
if docker ps | grep -q "vpn"; then
    echo "VPN container is running - will use VPN network"
    
    # Create a temporary configuration file with VPN settings
    cat > "/Users/vegard/Developer/GraphOS/graph_os/.devcontainer/devcontainer.local.json" << EOF
{
  "name": "GraphOS Elixir",
  "dockerFile": "Dockerfile",
  "postCreateCommand": "mix deps.get && mix compile && npm install -g @anthropic-ai/claude-code && .devcontainer/claude-auth.sh",
  "mounts": [
    "source=\${localEnv:HOME}/.env,target=/home/coder/.env,type=bind,readonly",
    "source=\${localEnv:HOME}/.config/anthropic,target=/home/coder/.config/anthropic,type=bind",
    "source=\${localEnv:HOME}/.cache/anthropic,target=/home/coder/.cache/anthropic,type=bind"
  ],
  "runArgs": ["--network=container:vpn"],
  "customizations": {
    "vscode": {
      "extensions": [
        "jakebecker.elixir-ls",
        "msaraiva.surface",
        "phoenixframework.phoenix",
        "anthropic.claude-vscode"
      ],
      "settings": {
        "elixirLS.dialyzerEnabled": true,
        "editor.formatOnSave": true
      }
    }
  },
  "features": {
    "ghcr.io/devcontainers/features/node:1": {
      "version": "lts"
    },
    "ghcr.io/devcontainers/features/git:1": {},
    "ghcr.io/devcontainers/features/github-cli:1": {},
    "ghcr.io/devcontainers-contrib/features/tmux:2": {},
    "ghcr.io/devcontainers/features/dotfiles:1": {
      "repository": "vegardkrogh/dotfiles",
      "installCommand": "install.sh"
    }
  }
}
EOF
else
    echo "VPN container is not running - will use standard network"
    
    # Use the standard configuration (the regular devcontainer.json will be used)
    rm -f "/Users/vegard/Developer/GraphOS/graph_os/.devcontainer/devcontainer.local.json" 2>/dev/null
fi

# Make the temporary file executable
chmod +x "/Users/vegard/Developer/GraphOS/graph_os/.devcontainer/claude-auth.sh"