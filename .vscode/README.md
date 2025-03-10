# VS Code Integration for GraphOS MCP Tasks

This directory contains configuration files for Visual Studio Code that enable easy access to MCP tasks through the VS Code interface.

## Setup

1. Make sure you have the recommended extensions installed:
   - **Task Buttons** (`spencerwmiles.vscode-task-buttons`): Required for showing task buttons in the status bar
   - **ElixirLS** (`jakebecker.elixir-ls`): For Elixir language support
   - **Elixir Formatter** (`saratravi.elixir-formatter`): For code formatting

   You should see a notification to install these when you open the project for the first time.

2. After installing the Task Buttons extension, restart VS Code for the buttons to appear in the status bar.

## Available Task Buttons

Once set up, you'll see these buttons in the VS Code status bar:

- **🔍 Inspector**: Start the MCP server with the full HTML/JS inspector UI
- **🐞 Debug**: Start the MCP server with debug mode (JSON API only)
- **📡 SSE**: Start the MCP server with SSE endpoint only
- **🧪 Test Client**: Test the MCP client functionality
- **🧩 Test Types**: Run MCP type parity tests between Elixir and TypeScript

## Additional Tasks

You can access more tasks not shown as buttons via the VS Code Command Palette:

1. Press `Ctrl+Shift+P` (or `Cmd+Shift+P` on macOS)
2. Type "Run Task" and select it
3. Choose from the list of available MCP tasks

Additional tasks include:
- **MCP: Test Server**: Test basic Bandit server configuration
- **MCP: Test Endpoint**: Test the MCP.Endpoint module directly

## Note on Server Tasks

Only one server can run on port 4000 at a time. Be sure to terminate any running MCP server (using `Ctrl+C` in the terminal) before starting another one. 