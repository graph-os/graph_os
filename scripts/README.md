# GraphOS Development Scripts

These scripts provide command-line tools for working with the GraphOS project.

## Available Scripts

### devcontainer.sh

Start and connect to the development container without requiring VS Code.

```bash
# Start and connect to the container (interactive shell)
./scripts/devcontainer.sh

# Run a specific command in the container
./scripts/devcontainer.sh mix test
./scripts/devcontainer.sh elixir -v
```

This script:
- Automatically builds the container if needed
- Detects if the VPN container is running and connects to it
- Mounts your project files and environment variables
- Persists Claude Code authentication

### mcp.sh

Start the MCP server in various modes.

```bash
# Start the standard MCP server
./scripts/mcp.sh

# Start a specific mode
./scripts/mcp.sh sse
./scripts/mcp.sh stdio
./scripts/mcp.sh debug
./scripts/mcp.sh inspect
```

### dev.sh

Start the Phoenix development server.

```bash
# Start the development server
./scripts/dev.sh
```

## Tips

- All scripts maintain the same container, so your changes persist between sessions
- Environment variables from ~/.env are automatically loaded
- The container has the same development environment as the VS Code devcontainer