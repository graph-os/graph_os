# GraphOS Documentation

This directory contains the centralized documentation for the GraphOS project. Documentation files are stored here and symlinked to their respective locations in the project.

## Structure

- **Top-level documentation**: General project documentation
  - `ARCHITECTURE.md`: Overall system architecture
  - `BOUNDARIES.md`: Project-wide component boundaries and responsibilities
  - `CLAUDE.md`: Development guide for Claude AI assistant
  - `HANDOFFS.md`: Cross-component task handoffs and coordination
  - `REFACTORING.md`: Refactoring guidelines and plans
  - `TASKS.md`: Current and planned tasks
  - `index.md`: Documentation index for quick navigation

## Maintenance Guidelines

1. **Always edit files in this directory**, not the symlinked copies
2. **Keep documentation up-to-date** with code changes
3. **Cross-reference** between related documentation files
4. When adding new common documentation:
   - Add it to this directory
   - Update symlinks as needed
   - Update this README.md if necessary

## Symlink Convention

The following files are symlinked to their respective locations:

1. Top-level files:
   - `/ARCHITECTURE.md` → `/instructions/ARCHITECTURE.md`
   - `/BOUNDARIES.md` → `/instructions/BOUNDARIES.md`
   - `/CLAUDE.md` → `/instructions/CLAUDE.md`
   - `/HANDOFFS.md` → `/instructions/HANDOFFS.md`
   - `/REFACTORING.md` → `/instructions/REFACTORING.md`
   - `/TASKS.md` → `/instructions/TASKS.md`

2. App-specific documentation:
   - Each app directory contains a symlink to the centralized documentation

3. Each app maintains its own README.md (not symlinked) with app-specific details and references to the centralized documentation.

## Adding New Documentation

To add new common documentation:

1. Create the file in the appropriate location in `/instructions`
2. Create a symlink from the target location to this file
3. Update relevant README files to reference the new documentation

## Documentation Guidelines

- Keep documentation clear, concise, and up-to-date
- Use Markdown formatting consistently
- Include examples where appropriate
- Cross-reference related documentation
- Document boundaries and interfaces thoroughly
- Update documentation when making significant changes to code