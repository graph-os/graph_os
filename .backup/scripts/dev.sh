#!/bin/bash

# Script to start the Phoenix development server in the devcontainer
# Usage: ./scripts/dev.sh

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Starting Phoenix development server..."
"${SCRIPT_DIR}/devcontainer.sh" mix dev.server