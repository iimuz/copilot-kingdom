# Troubleshooting Guide

Common issues and solutions for the multi-worktree agent system.

## Symlink Issues

### Broken Symlinks

**Symptom**: `ls -la worktrees/shogun/queue` shows a broken symlink (red/flashing in terminal)

**Cause**: Worktrees moved or symlink targets deleted

**Solution**:

```bash
# Check symlink status
readlink worktrees/shogun/queue
ls -la worktrees/karo-1/shared_context/

# Recreate symlinks
cd worktrees/shogun
rm queue dashboard.md
ln -s "$(cd ../karo-1 && pwd)/shared_context" queue
ln -s "$(cd ../karo-1 && pwd)/dashboard.md" dashboard.md

# Verify
readlink queue
```

### Symlink Permissions

**Symptom**: "Permission denied" when accessing `queue/` or `dashboard.md` from Shogun

**Cause**: File permissions on target directory/file

**Solution**:

```bash
# Fix permissions on Karo's shared context
chmod 755 worktrees/karo-1/shared_context
chmod 644 worktrees/karo-1/shared_context/shogun_to_karo.yaml
chmod 644 worktrees/karo-1/dashboard.md
```

### Symlinks Not Created

**Symptom**: Departure script completes but symlinks missing

**Cause**: Filesystem doesn't support symlinks or insufficient permissions

**Solution**:

```bash
# Test symlink support
ln -s /tmp/test_target /tmp/test_link
readlink /tmp/test_link
rm /tmp/test_link

# If this fails, your filesystem doesn't support symlinks
# Options:
# 1. Use a different filesystem (ext4, APFS, NTFS with permissions)
# 2. Run script with appropriate permissions
# 3. Modify system to use file copying instead (not recommended)
```

## Worktree Issues

### Worktree Already Exists

**Symptom**: `fatal: 'worktrees/shogun' already exists`

**Cause**: Previous worktree not cleaned up properly

**Solution**:

```bash
# List all worktrees
git worktree list

# Remove specific worktree
git worktree remove worktrees/shogun --force

# Clean up directory if still exists
rm -rf worktrees/shogun

# Re-run departure script
./scripts/worktree_departure.sh
```

### Cannot Remove Worktree

**Symptom**: `fatal: 'worktrees/shogun' contains modified or untracked files`

**Cause**: Working directory has uncommitted changes

**Solution**:

```bash
# Option 1: Commit changes
cd worktrees/shogun
git add .
git commit -m "Save work before cleanup"
cd ../..
git worktree remove worktrees/shogun

# Option 2: Discard changes
git worktree remove worktrees/shogun --force
```

### Worktree on Wrong Branch

**Symptom**: Worktree created on unexpected branch

**Cause**: Script created worktree from current HEAD

**Solution**:

```bash
# Check current branch in worktree
cd worktrees/shogun
git branch

# Switch to desired branch
git checkout main  # or your preferred branch

# Or recreate worktree on specific branch
cd ../..
git worktree remove worktrees/shogun
git worktree add worktrees/shogun main
```

## Tmux Issues

### Session Already Exists

**Symptom**: `duplicate session: multi`

**Cause**: Previous session not terminated

**Solution**:

```bash
# List sessions
tmux list-sessions

# Kill existing session
tmux kill-session -t multi

# Re-run departure script
./scripts/worktree_departure.sh
```

### Cannot Attach to Session

**Symptom**: `can't find session: multi`

**Cause**: Session was killed or never created

**Solution**:

```bash
# Check if session exists
tmux list-sessions

# If not, run departure script again
./scripts/worktree_departure.sh

# Attach to session
tmux attach-session -t multi
```

### Panes in Wrong Directories

**Symptom**: Pane shows wrong working directory

**Cause**: Environment setup failed during startup

**Solution**:

```bash
# Manually navigate in each pane
# Pane 0 (Shogun):
cd /path/to/copilot-kingdom/worktrees/shogun

# Pane 1 (Karo):
cd /path/to/copilot-kingdom/worktrees/karo-1

# Or restart the session
tmux kill-session -t multi
./scripts/worktree_departure.sh
```

## Communication Issues

### Shogun Cannot Write to queue/

**Symptom**: Error when Shogun tries to write `queue/shogun_to_karo.yaml`

**Cause**: Symlink broken or permissions issue

**Solution**:

```bash
# Verify symlink
cd worktrees/shogun
readlink queue
ls -la queue/

# Recreate if broken
rm queue
ln -s "$(cd ../karo-1 && pwd)/shared_context" queue

# Test write access
echo "test" > queue/test.txt
cat ../karo-1/shared_context/test.txt
rm queue/test.txt
```

### Karo Not Detecting Tasks

**Symptom**: Shogun writes task but Karo doesn't respond

**Cause**:

1. Karo not monitoring the file
2. File write not flushed
3. Notification not sent

**Solution**:

```bash
# Check if file exists in Karo's workspace
cat worktrees/karo-1/shared_context/shogun_to_karo.yaml

# Verify Karo is running
tmux list-panes -t multi -F "#{pane_index} #{pane_pid}"

# Send manual notification to Karo pane
tmux send-keys -t multi:agents.1 "# New task available" Enter
```

### Dashboard Not Updating

**Symptom**: Shogun's `dashboard.md` shows stale data

**Cause**: Symlink issue or Karo not writing

**Solution**:

```bash
# Verify symlink
cd worktrees/shogun
readlink dashboard.md
cat dashboard.md

# Compare with real file
cat ../karo-1/dashboard.md

# If different, symlink is broken - recreate
rm dashboard.md
ln -s "$(cd ../karo-1 && pwd)/dashboard.md" dashboard.md
```

## Performance Issues

### High CPU Usage

**Symptom**: System slow, high CPU usage

**Cause**: Multiple Copilot CLI instances running

**Solution**:

```bash
# Check running Copilot processes
ps aux | grep copilot

# Should see only 2 instances (Shogun + Karo)
# If more, kill extras
pkill -f "copilot.*agent"

# Restart system cleanly
./scripts/worktree_departure.sh
```

### Slow Task Execution

**Symptom**: Tasks take longer than expected

**Cause**: Subagent creation overhead or model choice

**Solution**:

1. Use faster models for Karo (e.g., Haiku instead of Opus)
2. Adjust subagent parameters in Karo's instructions
3. For simple tasks, let Shogun handle directly instead of delegating

## Script Issues

### Departure Script Fails

**Symptom**: `worktree_departure.sh` exits with error

**Cause**: Various - check error message

**Common Solutions**:

```bash
# Run with verbose output
bash -x ./scripts/worktree_departure.sh 2>&1 | tee startup.log

# Check prerequisites
which git tmux gh

# Verify git repository
git status

# Check for existing resources
git worktree list
tmux list-sessions
```

### Script Validation Failure

**Symptom**: "Symlink validation failed" message

**Cause**: Symlinks not created properly

**Solution**:

```bash
# Check what failed
ls -la worktrees/shogun/queue
ls -la worktrees/shogun/dashboard.md

# Review startup.log for detailed errors
cat startup.log | grep ERROR

# Clean up and retry
git worktree remove worktrees/shogun --force
git worktree remove worktrees/karo-1 --force
rm -rf worktrees/
./scripts/worktree_departure.sh
```

## Agent Behavior Issues

### Shogun Not Delegating

**Symptom**: Shogun always works directly, never delegates to Karo

**Cause**: Agent instructions unclear or task seems simple

**Solution**:

1. Explicitly request delegation: "Delegate this complex task to Karo"
2. Make task more complex/parallel-friendly
3. Check Shogun's instruction file for delegation criteria

### Karo Not Using Subagents

**Symptom**: Karo works directly instead of creating subagents

**Cause**: Task seems simple enough for direct execution

**Solution**:

1. This is often optimal - Karo makes intelligent decisions
2. If you want to force subagent usage, specify in task description
3. Check Karo's instruction file for subagent usage patterns

## Getting Help

If issues persist:

1. Check logs in each workspace:

   ```bash
   cat worktrees/shogun/copilot.log
   cat worktrees/karo-1/copilot.log
   ```

2. Review tmux pane history:

   ```bash
   tmux capture-pane -t multi:agents.0 -p -S -1000 > shogun.log
   tmux capture-pane -t multi:agents.1 -p -S -1000 > karo.log
   ```

3. Validate system state:

   ```bash
   git worktree list
   tmux list-sessions
   ls -la worktrees/shogun/queue
   readlink worktrees/shogun/queue
   cat worktrees/karo-1/shared_context/shogun_to_karo.yaml
   ```

4. Create an issue on GitHub with:
   - Error messages
   - System info (OS, Git version, tmux version)
   - Steps to reproduce
   - Relevant log snippets
