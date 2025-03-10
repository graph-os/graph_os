# GraphOS

GraphOS is a modular, distributed graph operating system built with Elixir.

## Project Structure

GraphOS is organized as an umbrella application with multiple independent components:

* **GraphOS.Graph** (`graph_os_graph`): Core graph library providing data structures, algorithms, and storage
* **GraphOS.Core** (`graph_os_core`): OS functions such as access control and security
* **GraphOS.MCP** (`graph_os_mcp`): Model Context Protocol implementation for AI/LLM integration
* **GraphOS.Livebook** (`graph_os_livebook`): Livebook integration for interactive graph analysis

## Installation

Each component can be used independently by adding it to your dependencies:

```elixir
def deps do
  [
    {:graph_os_graph, "~> 0.1.0"},
    # Optional components
    {:graph_os_core, "~> 0.1.0"},
    {:graph_os_mcp, "~> 0.1.0"},
    {:graph_os_distributed, "~> 0.1.0"},
    {:graph_os_livebook, "~> 0.1.0"},
    {:graph_os_phoenix, "~> 0.1.0"}
  ]
end
```

## Running the Project

### Starting the Entire Umbrella Application

To start all components together:

```bash
# Clone the repository
git clone https://github.com/graph-os/graph_os.git
cd graph_os

# Get dependencies
mix deps.get

# Compile
mix compile

# Start the application
iex -S mix
```

### Starting Individual Components

Each component can be started independently:

#### GraphOS.Graph

```bash
cd graph_os/apps/graph_os_graph
iex -S mix
```

This will start the graph library with ETS storage.

#### GraphOS.Core

```bash
cd graph_os/apps/graph_os_core
iex -S mix
```

This will start the core OS services like access control.

#### GraphOS.MCP

```bash
cd graph_os/apps/graph_os_mcp
iex -S mix
```

This will start the MCP protocol server for AI/LLM integration.

## Development

### Development Mode

GraphOS includes a development mode that provides a more interactive development experience:

- **Live Code Reloading**: Changes to Elixir files are automatically recompiled
- **MCP Endpoint**: Provides access to the CodeGraph functionality 
- **Graph Viewer**: Visualize graph content of files and modules

To start the development server:

```bash
mix mcp.dev
```

This will start the server on http://127.0.0.1:4000 by default.

For more details, see the [Development Mode Documentation](apps/graph_os_mcp/docs/developer_mode.md).

## VS Code Extension

This repository includes a custom VS Code extension to enhance development with GraphOS. The extension provides a dedicated UI for managing server tasks, running mix tasks, and accessing various tools directly from the VS Code interface.

### Features

- Server management (start, stop, restart, join tmux sessions)
- Mix task discovery and execution
- MCP tools integration (Inspector, Debug, SSE)
- Browser integration
- Status bar buttons for quick access

### Note on Configuration Files

The VS Code extension **replaces the need** for custom configuration in:
- `.vscode/settings.json` (with the "actionButtons" configuration)
- `.vscode/tasks.json` (with task definitions)

Once the extension is installed, you can safely remove these configurations as the extension provides the same functionality through its UI.

### Installation

To build and install the extension:

1. Navigate to the extension directory:
   ```
   cd vscode-graphos
   ```

2. Install dependencies:
   ```
   npm install
   ```

3. Build the extension:
   ```
   npm run compile
   ```

4. Package the extension:
   ```
   npm run package
   ```

5. Install the extension in VS Code:
   - Open VS Code
   - Press Ctrl+Shift+P (or Cmd+Shift+P on macOS)
   - Select "Extensions: Install from VSIX..."
   - Choose the file `vscode-graphos/vscode-graphos-0.1.0.vsix`

### Usage

The extension provides several ways to interact with GraphOS:

1. **Status Bar Buttons**: Clickable buttons at the bottom of VS Code for common actions
2. **GraphOS Explorer**: An Activity Bar icon that opens a sidebar with server controls
3. **Mix Tasks Browser**: A treeview for discovering and running mix tasks
4. **Command Palette**: All functionality is available via commands (Ctrl/Cmd+Shift+P)

See the [extension README](./vscode-graphos/README.md) for more details.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

