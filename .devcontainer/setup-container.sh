#!/bin/bash
set -e

# Script to set up the GraphOS development container
# This can be run regardless of how the container is started (VS Code or shell)

# Set hostname
echo "Setting hostname to GraphOS..."
sudo hostnamectl set-hostname GraphOS 2>/dev/null || echo "GraphOS" | sudo tee /etc/hostname

# Set up prompt to indicate GraphOS environment
if ! grep -q "\[GraphOS\]" ~/.bashrc; then
    echo 'export PS1="\[\e[32m\][GraphOS]\[\e[m\] \[\e[34m\]\w\[\e[m\] $ "' >> ~/.bashrc
fi

# Ensure npm global bin is in PATH (in case it's not already there)
if ! grep -q "export PATH=\$PATH:\$(npm bin -g)" ~/.bashrc; then
    echo 'export PATH=$PATH:$(npm bin -g)' >> ~/.bashrc
fi

# Verify Claude CLI is available
if command -v claude &> /dev/null; then
    echo "Claude CLI is installed and available."
else
    echo "Warning: Claude CLI not found in PATH."
fi

echo "GraphOS development environment setup complete!"