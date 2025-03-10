import * as cp from 'child_process';
import * as vscode from 'vscode';
import * as fs from 'fs';
import * as path from 'path';

/**
 * Execute a shell command and return the output
 * @param command The command to execute
 * @param captureOutput Whether to capture the output
 * @param workingDir Optional working directory
 * @returns The command output
 */
export function executeCommand(
  command: string, 
  captureOutput: boolean = false, 
  workingDir?: string
): Promise<string> {
  return new Promise((resolve, reject) => {
    const cwd = workingDir || getUmbrellaRootPath() || getWorkspacePath();
    
    const options: cp.ExecOptions = {
      cwd,
      maxBuffer: 1024 * 1024 * 5 // 5MB buffer to handle large outputs
    };
    
    console.log(`Executing command: ${command} in directory: ${cwd}`);
    
    if (captureOutput) {
      cp.exec(command, options, (error, stdout, stderr) => {
        if (error) {
          console.error(`Command execution error: ${error.message}`);
          console.error(`Command stderr: ${stderr}`);
          reject(error);
          return;
        }
        resolve(stdout.toString());
      });
    } else {
      cp.exec(command, options, (error) => {
        if (error) {
          console.error(`Command execution error: ${error.message}`);
          reject(error);
          return;
        }
        resolve('');
      });
    }
  });
}

/**
 * Get the root path of the workspace
 */
export function getWorkspacePath(): string | undefined {
  const folders = vscode.workspace.workspaceFolders;
  if (folders && folders.length > 0) {
    return folders[0].uri.fsPath;
  }
  return undefined;
}

/**
 * Find the umbrella project root by looking for a mix.exs file
 * and apps directory together in the same directory
 */
export function getUmbrellaRootPath(): string | undefined {
  const workspacePath = getWorkspacePath();
  if (!workspacePath) return undefined;
  
  // Check if we're already at the umbrella root
  if (isUmbrellaRoot(workspacePath)) {
    return workspacePath;
  }
  
  // Check for "apps" directory in case we're in a subdirectory
  const appsPath = path.join(workspacePath, '..', 'apps');
  const parentPath = path.join(workspacePath, '..');
  
  if (fs.existsSync(appsPath) && isUmbrellaRoot(parentPath)) {
    return parentPath;
  }
  
  // Try looking for the apps directory by walking up the tree
  let currentPath = workspacePath;
  const maxDepth = 5; // Don't go too far up
  
  for (let i = 0; i < maxDepth; i++) {
    const parentPath = path.dirname(currentPath);
    if (isUmbrellaRoot(parentPath)) {
      return parentPath;
    }
    if (parentPath === currentPath) {
      break; // We've reached the root
    }
    currentPath = parentPath;
  }
  
  // If we can't find the umbrella root, at least try to find a directory with mix.exs
  currentPath = workspacePath;
  for (let i = 0; i < maxDepth; i++) {
    if (fs.existsSync(path.join(currentPath, 'mix.exs'))) {
      return currentPath;
    }
    const parentPath = path.dirname(currentPath);
    if (parentPath === currentPath) {
      break; // We've reached the root
    }
    currentPath = parentPath;
  }
  
  return undefined;
}

/**
 * Check if a directory is an umbrella project root
 */
function isUmbrellaRoot(dirPath: string): boolean {
  return (
    fs.existsSync(path.join(dirPath, 'mix.exs')) &&
    fs.existsSync(path.join(dirPath, 'apps')) &&
    fs.statSync(path.join(dirPath, 'apps')).isDirectory()
  );
}

/**
 * Check if a command exists
 */
export async function commandExists(command: string): Promise<boolean> {
  try {
    await executeCommand(`which ${command}`, true);
    return true;
  } catch (error) {
    return false;
  }
} 