import * as vscode from 'vscode';
import { ServerProvider } from './serverProvider';
import type { MixTask } from './taskProvider';
import { TaskProvider } from './taskProvider';
import { executeCommand } from './utils';

export async function activate(context: vscode.ExtensionContext) {
  console.log('GraphOS extension is now active');

  // Register the server and task providers
  const serverProvider = new ServerProvider();
  const taskProvider = new TaskProvider();

  vscode.window.registerTreeDataProvider('graphos-sidebar', serverProvider);
  vscode.window.registerTreeDataProvider('graphos-tasks', taskProvider);

  // Create two main status bar items with dropdown functionality
  let serverRunning = false;

  // MIX button
  const mixButton = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, 100);
  mixButton.text = "$(beaker) mix";
  mixButton.tooltip = "Mix Tasks";
  mixButton.command = "graphos.showMixMenu";
  mixButton.color = new vscode.ThemeColor('statusBarItem.prominentForeground');
  mixButton.backgroundColor = new vscode.ThemeColor('statusBarItem.prominentBackground');
  mixButton.show();

  // MCP button with status indicator
  const mcpButton = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, 99);
  mcpButton.text = "$(broadcast) mcp"; // Will update with status indicator
  mcpButton.tooltip = "Model Context Protocol";
  mcpButton.command = "graphos.showMcpMenu";
  mcpButton.color = new vscode.ThemeColor('statusBarItem.prominentForeground');
  mcpButton.backgroundColor = new vscode.ThemeColor('statusBarItem.prominentBackground');
  mcpButton.show();

  // Add status bar items to context subscriptions
  context.subscriptions.push(mixButton, mcpButton);

  // Function to update MCP button with server status
  const updateMcpButton = async () => {
    serverRunning = await checkServerRunning();
    mcpButton.text = serverRunning
      ? "$(broadcast) mcp $(debug-start)"
      : "$(broadcast) mcp $(debug-stop)";
    mcpButton.tooltip = `Model Context Protocol (Server ${serverRunning ? 'Running' : 'Stopped'})`;
  };

  // Initial update of MCP button
  await updateMcpButton();

  // Schedule regular updates (every 5 seconds)
  const statusInterval = setInterval(async () => {
    await updateMcpButton();
  }, 5000);

  // Ensure interval is cleared on deactivation
  context.subscriptions.push({ dispose: () => clearInterval(statusInterval) });

  // Register our commands (incorporating all the tasks.json functionality)
  context.subscriptions.push(
    // Mix menu command
    vscode.commands.registerCommand('graphos.showMixMenu', async () => {
      const tasks = await taskProvider.getTasks();
      const namespaces = new Map<string, MixTask[]>();

      // Group tasks by namespace
      for (const task of tasks) {
        const namespaceName = task.label.includes('.') ? task.label.split('.')[0] : 'other';
        if (!namespaces.has(namespaceName)) {
          namespaces.set(namespaceName, []);
        }
        namespaces.get(namespaceName)?.push(task);
      }

      // Create menu items
      const items: vscode.QuickPickItem[] = [];

      // First add common actions
      items.push({
        label: "$(list-unordered) Task Menu",
        description: "Open the task menu with all mix tasks"
      });

      items.push({ label: '$(dash) Namespaces', kind: vscode.QuickPickItemKind.Separator });

      // Add namespace items
      for (const [namespace, namespaceTasks] of namespaces.entries()) {
        items.push({
          label: `$(symbol-namespace) ${namespace}`,
          description: `${namespaceTasks.length} tasks`
        });
      }

      // Show quick pick
      const selected = await vscode.window.showQuickPick(items, {
        placeHolder: 'Select a Mix task or namespace'
      });

      if (!selected) return;

      if (selected.label === "$(list-unordered) Task Menu") {
        vscode.commands.executeCommand('graphos.showTaskMenu');
      } else if (selected.label.startsWith('$(symbol-namespace)')) {
        // Selected a namespace, show tasks in that namespace
        const namespace = selected.label.replace('$(symbol-namespace) ', '');
        const namespaceTasks = namespaces.get(namespace) || [];

        const taskItems = namespaceTasks.map(task => ({
          label: `$(terminal-bash) ${task.label}`,
          description: task.description
        }));

        const selectedTask = await vscode.window.showQuickPick(taskItems, {
          placeHolder: `Select a task from ${namespace}`
        });

        if (selectedTask) {
          const taskName = selectedTask.label.replace('$(terminal-bash) ', '');
          vscode.commands.executeCommand('graphos.runTask', taskName);
        }
      }
    }),

    // MCP menu command
    vscode.commands.registerCommand('graphos.showMcpMenu', async () => {
      const items: vscode.QuickPickItem[] = [];

      // Server control section
      items.push({ label: '$(vm) Server Control', kind: vscode.QuickPickItemKind.Separator });

      if (serverRunning) {
        items.push({
          label: "$(debug-stop) Stop Server",
          description: "Stop the GraphOS server"
        });
        items.push({
          label: "$(debug-restart) Restart Server",
          description: "Restart the GraphOS server"
        });
        items.push({
          label: "$(terminal) Join Server Session",
          description: "Join the GraphOS server session"
        });
      } else {
        items.push({
          label: "$(debug-start) Start Server",
          description: "Start the GraphOS server"
        });
      }

      items.push({ label: '$(browser) Server Tools', kind: vscode.QuickPickItemKind.Separator });

      // MCP tools
      items.push({
        label: "$(inspect) Inspector",
        description: "Open the MCP Inspector"
      });
      items.push({
        label: "$(bug) Debug Mode",
        description: "Open the MCP Debug mode"
      });
      items.push({
        label: "$(broadcast) SSE",
        description: "Open the SSE endpoint"
      });

      // Test tools
      items.push({ label: '$(beaker) Test Tools', kind: vscode.QuickPickItemKind.Separator });

      items.push({
        label: "$(beaker) Test Client",
        description: "Run the MCP test client"
      });
      items.push({
        label: "$(symbol-enum) Test Types",
        description: "Run MCP type parity tests"
      });
      items.push({
        label: "$(server) Test Server",
        description: "Run MCP test server"
      });
      items.push({
        label: "$(globe) Test Endpoint",
        description: "Run MCP test endpoint"
      });

      // Show quick pick
      const selected = await vscode.window.showQuickPick(items, {
        placeHolder: 'Select MCP action'
      });

      if (!selected) return;

      // Handle selection
      switch (selected.label) {
        case "$(debug-stop) Stop Server":
          vscode.commands.executeCommand('graphos.stopServer');
          break;
        case "$(debug-restart) Restart Server":
          vscode.commands.executeCommand('graphos.restartServer');
          break;
        case "$(terminal) Join Server Session":
          vscode.commands.executeCommand('graphos.joinServer');
          break;
        case "$(debug-start) Start Server":
          vscode.commands.executeCommand('graphos.startServer');
          break;
        case "$(inspect) Inspector":
          vscode.commands.executeCommand('graphos.openInspector');
          break;
        case "$(bug) Debug Mode":
          vscode.commands.executeCommand('graphos.openDebug');
          break;
        case "$(broadcast) SSE":
          vscode.commands.executeCommand('graphos.openSSE');
          break;
        case "$(beaker) Test Client":
          vscode.commands.executeCommand('graphos.runTestClient');
          break;
        case "$(symbol-enum) Test Types":
          vscode.commands.executeCommand('graphos.runTestTypes');
          break;
        case "$(server) Test Server":
          vscode.commands.executeCommand('graphos.runTestServer');
          break;
        case "$(globe) Test Endpoint":
          vscode.commands.executeCommand('graphos.runTestEndpoint');
          break;
      }
    }),

    // Server management commands
    vscode.commands.registerCommand('graphos.startServer', async () => {
      const terminal = vscode.window.createTerminal('GraphOS Server');
      terminal.sendText('mix dev.server start');
      terminal.show();

      // Open browser after a delay to ensure server has started
      setTimeout(() => {
        executeCommand('open http://localhost:4000');
      }, 3000);

      serverProvider.refresh();
      await updateMcpButton();
    }),

    vscode.commands.registerCommand('graphos.stopServer', async () => {
      const terminal = vscode.window.createTerminal('GraphOS Server');
      terminal.sendText('mix dev.server stop');
      terminal.show();
      serverProvider.refresh();
      await updateMcpButton();
    }),

    vscode.commands.registerCommand('graphos.restartServer', async () => {
      const terminal = vscode.window.createTerminal('GraphOS Server');
      terminal.sendText('mix dev.server restart');
      terminal.show();

      // Open browser after a delay to ensure server has restarted
      setTimeout(() => {
        executeCommand('open http://localhost:4000');
      }, 3000);

      serverProvider.refresh();
      await updateMcpButton();
    }),

    vscode.commands.registerCommand('graphos.joinServer', async () => {
      const terminal = vscode.window.createTerminal('GraphOS Server Session');
      terminal.sendText('mix dev.server join');
      terminal.show();
    }),

    vscode.commands.registerCommand('graphos.checkServerStatus', async () => {
      const terminal = vscode.window.createTerminal('GraphOS Server Status');
      terminal.sendText('mix dev.server status');
      terminal.show();
      serverProvider.refresh();
      await updateMcpButton();
    }),

    vscode.commands.registerCommand('graphos.openBrowser', async () => {
      executeCommand('open http://localhost:4000');
    }),

    // MCP tool commands
    vscode.commands.registerCommand('graphos.openInspector', async () => {
      const isRunning = await checkServerRunning();

      if (isRunning) {
        vscode.window.showInformationMessage('Using existing server session...');
        executeCommand('open http://localhost:4000/inspector');
      } else {
        const terminal = vscode.window.createTerminal('GraphOS Inspector');
        terminal.sendText('mix mcp.inspect');
        terminal.show();

        // Open browser after a delay to ensure inspector has started
        setTimeout(() => {
          executeCommand('open http://localhost:4000/inspector');
        }, 3000);
      }

      serverProvider.refresh();
      await updateMcpButton();
    }),

    vscode.commands.registerCommand('graphos.openDebug', async () => {
      const isRunning = await checkServerRunning();

      if (isRunning) {
        vscode.window.showInformationMessage('Using existing server session...');
        executeCommand('open http://localhost:4000/debug/api');
      } else {
        const terminal = vscode.window.createTerminal('GraphOS Debug');
        terminal.sendText('mix mcp.debug');
        terminal.show();

        // Open browser after a delay to ensure debug has started
        setTimeout(() => {
          executeCommand('open http://localhost:4000/debug/api');
        }, 3000);
      }

      serverProvider.refresh();
      await updateMcpButton();
    }),

    vscode.commands.registerCommand('graphos.openSSE', async () => {
      const isRunning = await checkServerRunning();

      if (isRunning) {
        vscode.window.showInformationMessage('Using existing server session...');
        executeCommand('open http://localhost:4000/sse');
      } else {
        const terminal = vscode.window.createTerminal('GraphOS SSE');
        terminal.sendText('mix mcp.sse');
        terminal.show();

        // Open browser after a delay to ensure SSE has started
        setTimeout(() => {
          executeCommand('open http://localhost:4000/sse');
        }, 3000);
      }

      serverProvider.refresh();
      await updateMcpButton();
    }),

    // Test commands
    vscode.commands.registerCommand('graphos.runTestClient', async () => {
      const terminal = vscode.window.createTerminal('GraphOS Test Client');
      terminal.sendText('mix mcp.test_client');
      terminal.show();
    }),

    vscode.commands.registerCommand('graphos.runTestTypes', async () => {
      const terminal = vscode.window.createTerminal('GraphOS Test Types');
      terminal.sendText('mix mcp.test_types');
      terminal.show();
    }),

    vscode.commands.registerCommand('graphos.runTestServer', async () => {
      const terminal = vscode.window.createTerminal('GraphOS Test Server');
      terminal.sendText('mix mcp.test_server');
      terminal.show();
    }),

    vscode.commands.registerCommand('graphos.runTestEndpoint', async () => {
      const terminal = vscode.window.createTerminal('GraphOS Test Endpoint');
      terminal.sendText('mix mcp.test_endpoint');
      terminal.show();
    }),

    // Task menu commands
    vscode.commands.registerCommand('graphos.showTaskMenu', async () => {
      const terminal = vscode.window.createTerminal('GraphOS Task Menu');
      terminal.sendText('mix dev.menu');
      terminal.show();
    }),

    vscode.commands.registerCommand('graphos.showMCPTasks', async () => {
      const terminal = vscode.window.createTerminal('GraphOS MCP Tasks');
      terminal.sendText('mix dev.menu --filter=mcp');
      terminal.show();
    }),

    vscode.commands.registerCommand('graphos.showDevTasks', async () => {
      const terminal = vscode.window.createTerminal('GraphOS Dev Tasks');
      terminal.sendText('mix dev.menu --filter=dev');
      terminal.show();
    }),

    vscode.commands.registerCommand('graphos.listTasks', async () => {
      const terminal = vscode.window.createTerminal('GraphOS Task List');
      terminal.sendText('mix dev.tasks');
      terminal.show();
    }),

    // General task command
    vscode.commands.registerCommand('graphos.runTask', async (taskName?: string) => {
      if (!taskName) {
        // If no task is provided, show a quick pick to select a task
        const tasks = await taskProvider.getTasks();

        // Define the interface for the quick pick items
        interface QuickPickItem {
          label: string;
          description: string;
        }

        const selectedTask = await vscode.window.showQuickPick<QuickPickItem>(
          tasks.map((task: MixTask) => ({ label: task.label, description: task.description })),
          { placeHolder: 'Select a mix task to run' }
        );

        if (selectedTask) {
          taskName = selectedTask.label;
        } else {
          return;
        }
      }

      const terminal = vscode.window.createTerminal(`GraphOS Task: ${taskName}`);
      terminal.sendText(`mix ${taskName}`);
      terminal.show();
    }),

    vscode.commands.registerCommand('graphos.refreshTasks', () => {
      taskProvider.refresh();
    })
  );

  // Initial refresh
  serverProvider.refresh();
  taskProvider.refresh();
}

async function checkServerRunning(): Promise<boolean> {
  try {
    // Try using the dev.server status command
    const result = await executeCommand('mix dev.server status', true);
    return result.includes('Phoenix server is running');
  } catch (error) {
    // If the command fails, try a more generic approach
    try {
      // Check for a running Phoenix server by checking for a PID file or process
      const processResult = await executeCommand('ps aux | grep "[p]hoenix.*server" || echo "No server found"', true);
      return !processResult.includes('No server found');
    } catch (secondError) {
      console.error('Failed to check server status:', secondError);
      return false;
    }
  }
}

export function deactivate() {
  // Clean up resources
} 