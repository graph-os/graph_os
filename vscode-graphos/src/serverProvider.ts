import * as vscode from 'vscode';
import { executeCommand } from './utils';

export class ServerItem extends vscode.TreeItem {
  constructor(
    public readonly label: string,
    public readonly collapsibleState: vscode.TreeItemCollapsibleState,
    public readonly command?: vscode.Command
  ) {
    super(label, collapsibleState);
  }
}

export class ServerProvider implements vscode.TreeDataProvider<ServerItem> {
  private _onDidChangeTreeData: vscode.EventEmitter<ServerItem | undefined | null | void> = new vscode.EventEmitter<ServerItem | undefined | null | void>();
  readonly onDidChangeTreeData: vscode.Event<ServerItem | undefined | null | void> = this._onDidChangeTreeData.event;

  private _serverRunning: boolean = false;

  refresh(): void {
    this.checkServerStatus().then(running => {
      this._serverRunning = running;
      this._onDidChangeTreeData.fire();
    });
  }

  getTreeItem(element: ServerItem): vscode.TreeItem {
    return element;
  }

  async getChildren(element?: ServerItem): Promise<ServerItem[]> {
    if (element) {
      return [];
    }

    const items: ServerItem[] = [];

    // Server status
    const statusItem = new ServerItem(
      `Server: ${this._serverRunning ? 'Running' : 'Stopped'}`,
      vscode.TreeItemCollapsibleState.None
    );
    
    statusItem.iconPath = this._serverRunning 
      ? new vscode.ThemeIcon('debug-start', new vscode.ThemeColor('terminal.ansiGreen'))
      : new vscode.ThemeIcon('debug-stop', new vscode.ThemeColor('terminal.ansiRed'));
    
    items.push(statusItem);

    // Server actions
    if (this._serverRunning) {
      items.push(
        new ServerItem('Stop Server', vscode.TreeItemCollapsibleState.None, {
          command: 'graphos.stopServer',
          title: 'Stop Server'
        }),
        new ServerItem('Restart Server', vscode.TreeItemCollapsibleState.None, {
          command: 'graphos.restartServer',
          title: 'Restart Server'
        }),
        new ServerItem('Join Server Session', vscode.TreeItemCollapsibleState.None, {
          command: 'graphos.joinServer',
          title: 'Join Server Session'
        })
      );
    } else {
      items.push(
        new ServerItem('Start Server', vscode.TreeItemCollapsibleState.None, {
          command: 'graphos.startServer',
          title: 'Start Server'
        })
      );
    }

    // Browser actions
    items.push(
      new ServerItem('Open in Browser', vscode.TreeItemCollapsibleState.None, {
        command: 'graphos.openBrowser',
        title: 'Open in Browser'
      })
    );

    // MCP actions
    items.push(
      new ServerItem('MCP', vscode.TreeItemCollapsibleState.Collapsed)
    );

    return items;
  }

  async getChildren2(element?: ServerItem): Promise<ServerItem[]> {
    if (!element) {
      return this.getChildren();
    }

    // Handle MCP submenu
    if (element.label === 'MCP') {
      return [
        new ServerItem('Inspector', vscode.TreeItemCollapsibleState.None, {
          command: 'graphos.openInspector',
          title: 'Open Inspector'
        }),
        new ServerItem('Debug Mode', vscode.TreeItemCollapsibleState.None, {
          command: 'graphos.openDebug',
          title: 'Open Debug Mode'
        }),
        new ServerItem('SSE', vscode.TreeItemCollapsibleState.None, {
          command: 'graphos.openSSE',
          title: 'Open SSE'
        })
      ];
    }

    return [];
  }

  private async checkServerStatus(): Promise<boolean> {
    try {
      const result = await executeCommand('mix dev.server status', true);
      return result.includes('Phoenix server is running');
    } catch (error) {
      return false;
    }
  }
} 