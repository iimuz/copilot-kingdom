# Troubleshooting Guide

Common issues and solutions for the multi-worktree agent system.

## Configuration Validation Errors

### Missing SHOGUN_PATH

**Symptom:** `SHOGUN_PATH is required and must point to an existing directory`

**Fix:**

```bash
export SHOGUN_PATH="/path/to/shogun"
```

### Empty KARO_PATHS

**Symptom:** `KARO_PATHS must include at least one path`

**Fix:**

```bash
export KARO_PATHS=("/path/to/karo-1")
```

### Duplicate Paths

**Symptom:** `Duplicate path detected`

**Fix:** Ensure `SHOGUN_PATH` is unique and each entry in `KARO_PATHS` is distinct.

### Permission Denied

**Symptom:** `No write permission for ...`

**Fix:** Ensure the parent directory for each Karo path and the Shogun context is writable.

```bash
chmod 755 /path/to
```

### Not a Git Repository

**Symptom:** `SHOGUN_PATH is not a git repository` or `Karo path exists but is not a git worktree`

**Fix:** Point `SHOGUN_PATH` and `KARO_PATHS` at valid git worktrees from the same repository.

## Symlink Issues

### Missing .agent/kingdom

**Symptom:** `.agent/kingdom` is missing in a Karo worktree

**Fix:** Re-run the script or recreate the symlink:

```bash
rm -rf /path/to/karo-1/.agent/kingdom
ln -s /path/to/shogun/.agent/kingdom/shogun /path/to/karo-1/.agent/kingdom
```

### Broken .agent/kingdom Symlink

**Symptom:** `readlink` fails or points to a missing target

**Fix:** Verify `SHOGUN_PATH` exists and re-run the script.

## Worktree Issues

### Worktree Already Exists

**Symptom:** `fatal: '<path>' already exists`

**Fix:**

```bash
git -C "$SHOGUN_PATH" worktree list
git -C "$SHOGUN_PATH" worktree remove /path/to/karo-1 --force
git -C "$SHOGUN_PATH" worktree prune
```

### Worktree on Wrong Branch

**Symptom:** Worktree created on an unexpected branch

**Fix:** Switch branches in the Karo worktree or adjust the script to use a different base branch.

## Tmux Issues

### Session Already Exists

**Symptom:** `duplicate session: multi`

**Fix:**

```bash
tmux list-sessions
tmux kill-session -t multi
```

### Panes in Wrong Directories

**Symptom:** Pane shows wrong working directory

**Fix:** Restart the session or manually `cd` to the correct Karo worktree path.

## Copilot Startup Issues

### Copilot CLI Not Starting

**Symptom:** No Copilot prompt in a Karo pane

**Fix:** Ensure `copilot` is on PATH and restart the tmux session.

## Useful Commands

```bash
./scripts/worktree_departure.sh --check
git -C "$SHOGUN_PATH" worktree list
tmux list-sessions
```
