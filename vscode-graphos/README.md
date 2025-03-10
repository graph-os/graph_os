# GraphOS VS Code Extension

A VS Code extension to manage GraphOS development and server tasks directly within the editor.

## Features

- Server management (start, stop, restart)
- Tmux session integration
- MCP tooling access (Inspector, Debug, SSE)
- Mix task discovery and execution
- Browser integration
- Status bar buttons with dropdown menus for quick access

## Installation

### Development Setup

1. Clone this repository
2. Navigate to the extension directory:
   ```
   cd vscode-graphos
   ```
3. Install dependencies:
   ```
   npm install
   ```
4. Open the extension in VS Code:
   ```
   code .
   ```
5. Press F5 to launch the extension in a new Development Host window

### Local Installation

After building the extension:

1. Open the Command Palette (Ctrl+Shift+P / Cmd+Shift+P)
2. Select "Extensions: Install from VSIX..."
3. Navigate to `vscode-graphos/vscode-graphos-0.1.0.vsix` and select it

## Usage

This extension replaces the need for custom configuration in `.vscode/settings.json` and `.vscode/tasks.json`. It provides:

1. **Status Bar Buttons**: Conveniently access all functionality directly from the VS Code status bar
   - **Mix Button**: Quick access to mix tasks organized by namespace
   - **MCP Button**: MCP tools with server status indicator (running/stopped)
   - Each button opens a dropdown menu with relevant commands

2. **GraphOS Explorer**: Available from the Activity Bar icon, it provides:
   - Server status and controls (start, stop, restart)
   - Browser integration
   - MCP tools (Inspector, Debug, SSE)

3. **Mix Tasks**: Browse and run available mix tasks
   - Organized by namespace
   - One-click task execution
   - Task documentation
   - Right-click options

## Status Bar Buttons

The extension provides two main status bar buttons for quick access:

### Mix Button ($(beaker) mix)
- Provides quick access to all Mix tasks
- Shows task namespaces in a dropdown menu
- Selecting a namespace shows all tasks within that namespace
- Also provides access to the Task Menu

### MCP Button ($(broadcast) mcp)
- Shows server status with indicator (running/stopped)
- Provides access to MCP tools and server control
- Organized sections:
  - Server Control (start/stop/restart based on current status)
  - Server Tools (Inspector, Debug, SSE)
  - Test Tools (Test Client, Test Types, Test Server, Test Endpoint)

## Commands

All functionality is also available as commands:

- **Menu Commands**
  - `GraphOS: Show Mix Menu` - Open the Mix tasks dropdown menu
  - `GraphOS: Show MCP Menu` - Open the MCP tools dropdown menu

- **Server Management**
  - `GraphOS: Start Server` - Start the Phoenix server in a tmux session
  - `GraphOS: Stop Server` - Stop the running server
  - `GraphOS: Restart Server` - Restart the server
  - `GraphOS: Join Server Session` - Join the tmux server session
  - `GraphOS: Check Server Status` - View the current server status
  - `GraphOS: Open in Browser` - Open the app in the default browser

- **MCP Tools**
  - `GraphOS: Open Inspector` - Open the MCP Inspector
  - `GraphOS: Open Debug Mode` - Open MCP Debug mode
  - `GraphOS: Open SSE` - Open the MCP SSE endpoint

- **Testing Tools**
  - `GraphOS: Run Test Client` - Run the MCP test client
  - `GraphOS: Run Test Types` - Run MCP type parity tests
  - `GraphOS: Run Test Server` - Test Bandit server configuration
  - `GraphOS: Run Test Endpoint` - Test MCP.Endpoint functionality

- **Task Management**
  - `GraphOS: Show Task Menu` - Show the interactive task menu
  - `GraphOS: Show MCP Tasks` - Show MCP-related tasks
  - `GraphOS: Show Dev Tasks` - Show Dev-related tasks
  - `GraphOS: List All Tasks` - List all available tasks
  - `GraphOS: Run Mix Task` - Run a specific mix task

## Development

### Building

```
npm run compile
```

### Packaging

```
npm run package
```

### Testing

```
npm run test
```

## License

MIT 