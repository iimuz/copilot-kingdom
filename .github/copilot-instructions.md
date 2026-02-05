## Project Overview

Configuration for parallel execution of multiple GitHub Copilot instances using git worktree.

## Critical Rules

### Code Organization

- Many small files over few large files
- High cohesion, low coupling
- 200-400 lines typical, 800 max per file
- Organize by feature/domain, not by type

### Code Style

- No emojis in code, comments, or documentation
- Immutability always - never mutate objects or arrays

### Security

- No hardcoded secrets
- Environment variables for sensitive data
- Validate all user inputs
- Parameterized queries only
- CSRF protection enabled

## File Structure

- `.github/`
  - `skills`: SKILL configuration for shared use across multiple Copilot instances
