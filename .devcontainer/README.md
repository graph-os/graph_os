# GraphOS Dev Container

This dev container provides a ready-to-use environment for GraphOS development with Elixir and the MCP server.

## Features

- Elixir 1.18 and supporting tools
- Node.js LTS for frontend development
- Claude Code CLI installation
- tmux for running server tasks
- Automatic dotfiles setup from vegardkrogh/dotfiles
- Pre-configured ports for MCP server (4000, 4001)
- VS Code extensions for Elixir and Phoenix development
- Environment variables from ~/.env automatically loaded
- Integration with VPN container for secure connectivity

## Environment Variables and Authentication

The container automatically mounts and loads your `~/.env` file, making your API keys and GitHub tokens available in the container environment. These are loaded when you open a new shell session.

### Claude Code Authentication Persistence

The container is configured to persist Claude Code authentication by mounting the following directories:
- `~/.config/anthropic` - Contains Claude authentication tokens
- `~/.cache/anthropic` - Contains Claude cache data

This ensures you don't need to re-authenticate Claude Code CLI between container restarts.

## VPN Integration

The devcontainer is configured to automatically detect if the VPN container named `vpn` is running:

1. If the VPN container is running, the devcontainer will use its network
2. If the VPN container is not running, the devcontainer will use the standard network

This provides flexibility to work both with and without the VPN connection. No manual configuration is needed - the initialization script handles this automatically.

To start the VPN container:

```bash
# Start the VPN container if needed
docker start vpn
```

## Starting the MCP Server

Use the included script to start the MCP server:

```bash
# Standard server
.devcontainer/start-mcp.sh

# SSE endpoint only
.devcontainer/start-mcp.sh sse

# STDIO interface
.devcontainer/start-mcp.sh stdio

# Debug mode
.devcontainer/start-mcp.sh debug

# Inspector UI
.devcontainer/start-mcp.sh inspect
```

## CLI Alternative

If you prefer not to use VS Code, you can use the CLI scripts in the `scripts` directory:

```bash
# Start and connect to the devcontainer
./scripts/devcontainer.sh

# Start the development server
./scripts/dev.sh

# Start an MCP server (with optional mode)
./scripts/mcp.sh [server|sse|stdio|debug|inspect]
```

These scripts provide the same development environment as the VS Code devcontainer, but can be used from any terminal.

## Development Commands

See CLAUDE.md for more project-specific commands and guidelines.