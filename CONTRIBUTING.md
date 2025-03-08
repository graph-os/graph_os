# GraphOS - Contributing Guidelines

## Project Structure

GraphOS is organized as an Elixir umbrella application with multiple independent components, each maintained in its own repository:

- **[graph_os_umbrella](https://github.com/graph-os/graph_os_umbrella)**: Main umbrella application repository
- **[graph_os_graph](https://github.com/graph-os/graph_os_graph)**: Core graph library with data structures and algorithms
- **[graph_os_core](https://github.com/graph-os/graph_os_core)**: OS functions such as access control and security
- **[graph_os_mcp](https://github.com/graph-os/graph_os_mcp)**: Model Context Protocol implementation for AI integration
- **[graph_os_livebook](https://github.com/graph-os/graph_os_livebook)**: Livebook integration for visualization

Each component exists as:
1. A subdirectory within the umbrella app (`/apps/component_name/`)
2. A standalone repository in the GitHub organization

## Git Rules

### Safe Commands

✅ **Safe Commands** (can be executed without confirmation):
- `git status`, `git log`, `git diff`
- `git branch`, `git checkout` (on existing branches)
- `git fetch`, `git pull`
- `git add` (specific files, not `git add .`)
- `git commit` (with meaningful messages)
- `git stash`, `git stash pop`

⚠️ **Require Confirmation** (must be approved by user):
- `git push` (to any branch)
- `git merge` (any merges)
- `git rebase`
- `git reset`
- `git checkout -b` (creating new branches)
- `git add .` (adding all files)

🚫 **Avoid Completely**:
- `git push --force`
- `git reset --hard` (without specific confirmation)
- `git clean -f`
- Commands that could result in data loss

## GitHub CLI Rules

The GitHub CLI (`gh`) is available for use with the following guidelines:

✅ **Safe Commands**:
- `gh repo view`
- `gh issue list`
- `gh pr list`
- `gh auth status`

⚠️ **Require Confirmation**:
- `gh repo create`
- `gh repo rename`
- `gh pr create`
- `gh release create`

🚫 **Avoid Without Explicit Instruction**:
- `gh repo delete`
- `gh repo archive`
- Any commands that modify permissions or settings

## Workflow Best Practices

1. **Umbrella Project Changes**:
   - Modifications to the umbrella structure should be performed in the umbrella repository
   - Individual app changes should be made in their respective repositories

2. **Dependencies**:
   - App repositories use `in_umbrella: true` for dependencies within the umbrella structure
   - External dependencies should specify version constraints

3. **Commits and PRs**:
   - Use descriptive commit messages in the format `type(scope): message`
   - Keep PRs focused on a single logical change
   - Include tests for new functionality

4. **Documentation**:
   - Update documentation when changing functionality
   - Use `@moduledoc` and `@doc` for all public modules and functions

## Working with GraphOS

### Running the Umbrella Application

```bash
# Clone the umbrella repository
git clone git@github.com:graph-os/graph_os_umbrella.git
cd graph_os_umbrella

# Get dependencies
mix deps.get

# Start the application
iex -S mix
```

### Running Individual Components

```bash
# Example for graph_os_livebook
cd apps/graph_os_livebook
iex -S mix
``` 