import * as vscode from 'vscode';
import { executeCommand, getWorkspacePath, getUmbrellaRootPath } from './utils';
import * as path from 'path';

export interface MixTask {
  label: string;
  description: string;
}

export class TaskItem extends vscode.TreeItem {
  constructor(
    public readonly label: string,
    public readonly description: string,
    public readonly collapsibleState: vscode.TreeItemCollapsibleState,
    public readonly command?: vscode.Command
  ) {
    super(label, collapsibleState);
    this.tooltip = description;
    this.description = description;
    
    // Set contextValue for tasks (this allows menus to target specific item types)
    if (collapsibleState === vscode.TreeItemCollapsibleState.None) {
      this.contextValue = 'taskItem';
    } else {
      this.contextValue = 'namespaceItem';
    }
  }
}

export class TaskProvider implements vscode.TreeDataProvider<TaskItem> {
  private _onDidChangeTreeData: vscode.EventEmitter<TaskItem | undefined | null | void> = new vscode.EventEmitter<TaskItem | undefined | null | void>();
  readonly onDidChangeTreeData: vscode.Event<TaskItem | undefined | null | void> = this._onDidChangeTreeData.event;

  private _tasks: MixTask[] = [];
  private _namespaces: Map<string, MixTask[]> = new Map();

  refresh(): void {
    this.loadTasks().then(() => {
      this._onDidChangeTreeData.fire();
    });
  }

  getTreeItem(element: TaskItem): vscode.TreeItem {
    return element;
  }

  async getChildren(element?: TaskItem): Promise<TaskItem[]> {
    if (!element) {
      // Root level - show namespaces
      return this.getNamespaces();
    } else {
      // Namespace level - show tasks in this namespace
      return this.getTasksInNamespace(element.label);
    }
  }

  async getTasks(): Promise<MixTask[]> {
    if (this._tasks.length === 0) {
      await this.loadTasks();
    }
    return this._tasks;
  }

  private async loadTasks(): Promise<void> {
    try {
      const umbrellaRoot = getUmbrellaRootPath();
      const workspacePath = getWorkspacePath();
      
      if (!umbrellaRoot && !workspacePath) {
        vscode.window.showWarningMessage('No Elixir project found. Please open a folder containing a mix.exs file.');
        return;
      }
      
      let output = '';
      let useDevTasks = true;
      
      try {
        // First try using the custom dev.tasks task
        output = await executeCommand('mix dev.tasks', true);
      } catch (error) {
        console.log('dev.tasks not available, falling back to mix help');
        useDevTasks = false;
        
        // Fallback to standard mix help
        try {
          output = await executeCommand('mix help', true);
        } catch (helpError) {
          vscode.window.showErrorMessage(`Failed to load Mix tasks: ${helpError}`);
          return;
        }
      }
      
      const lines = output.split('\n');

      // Clear existing tasks
      this._tasks = [];
      this._namespaces = new Map();

      let currentNamespace = '';
      
      if (useDevTasks) {
        // Parse output from dev.tasks
        for (const line of lines) {
          // Check if it's a namespace line (e.g. "phoenix")
          if (line.trim() && !line.startsWith(' ') && !line.startsWith('\t') && !line.includes('Available Mix Tasks:')) {
            currentNamespace = line.trim();
          } 
          // Check if it's a task line (starts with whitespace and has a task name)
          else if (line.trim() && (line.startsWith(' ') || line.startsWith('\t'))) {
            const match = line.trim().match(/^([a-z0-9._:]+)\s+(.*)/);
            if (match) {
              const taskName = match[1];
              const description = match[2] || '';
              
              const task: MixTask = {
                label: taskName,
                description: description
              };
              
              this._tasks.push(task);
              
              // Add to namespace map
              if (!this._namespaces.has(currentNamespace)) {
                this._namespaces.set(currentNamespace, []);
              }
              this._namespaces.get(currentNamespace)?.push(task);
            }
          }
        }
      } else {
        // Parse output from mix help
        let inTaskSection = false;
        
        for (const line of lines) {
          // Check for the start of the mix tasks section
          if (line.includes('mix') && line.includes('# ')) {
            inTaskSection = true;
            continue;
          }
          
          if (!inTaskSection) continue;
          
          // Skip empty lines and section headers
          if (!line.trim() || line.endsWith(':')) continue;
          
          // Parse task lines
          const match = line.trim().match(/^([a-z0-9._:]+)\s+#\s+(.*)/);
          if (match) {
            const taskName = match[1];
            const description = match[2] || '';
            
            // Determine namespace from task name
            const namespace = taskName.includes('.') 
              ? taskName.split('.')[0] 
              : 'mix';
              
            const task: MixTask = {
              label: taskName,
              description: description
            };
            
            this._tasks.push(task);
            
            // Add to namespace map
            if (!this._namespaces.has(namespace)) {
              this._namespaces.set(namespace, []);
            }
            this._namespaces.get(namespace)?.push(task);
          }
        }
        
        // If we couldn't find any tasks in the standard output, add a basic set
        if (this._tasks.length === 0) {
          this.addBasicTasks();
        }
      }
      
      // If we have no namespaces, create a default one
      if (this._namespaces.size === 0) {
        this._namespaces.set('mix', this._tasks);
      }
    } catch (error) {
      vscode.window.showErrorMessage(`Failed to load Mix tasks: ${error}`);
      // Add basic tasks as a fallback
      this.addBasicTasks();
    }
  }
  
  private addBasicTasks(): void {
    // Add some basic mix tasks that are commonly available
    const basicTasks = [
      { label: 'compile', description: 'Compiles source files' },
      { label: 'deps.get', description: 'Gets all out of date dependencies' },
      { label: 'deps.update', description: 'Updates the given dependencies' },
      { label: 'test', description: 'Runs a project\'s tests' },
      { label: 'help', description: 'Lists all available tasks' },
      { label: 'clean', description: 'Deletes generated application files' }
    ];
    
    this._tasks = basicTasks;
    this._namespaces.set('mix', basicTasks);
  }

  private async getNamespaces(): Promise<TaskItem[]> {
    if (this._namespaces.size === 0) {
      await this.loadTasks();
    }
    
    const namespaceItems: TaskItem[] = [];
    
    for (const [namespace, tasks] of this._namespaces.entries()) {
      const item = new TaskItem(
        namespace,
        `${tasks.length} tasks`,
        vscode.TreeItemCollapsibleState.Collapsed
      );
      
      item.iconPath = new vscode.ThemeIcon('symbol-namespace');
      namespaceItems.push(item);
    }
    
    return namespaceItems.sort((a, b) => a.label.localeCompare(b.label));
  }

  private async getTasksInNamespace(namespace: string): Promise<TaskItem[]> {
    const tasks = this._namespaces.get(namespace) || [];
    
    return tasks.map(task => {
      const item = new TaskItem(
        task.label,
        task.description,
        vscode.TreeItemCollapsibleState.None,
        {
          command: 'graphos.runTask',
          title: 'Run Task',
          arguments: [task.label]
        }
      );
      
      item.iconPath = new vscode.ThemeIcon('terminal-bash');
      return item;
    }).sort((a, b) => a.label.localeCompare(b.label));
  }
} 