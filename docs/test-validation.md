# Test Validation

## Baseline Checks

Run the validation checks after any script changes:

```bash
bash -n scripts/worktree_departure.sh
./scripts/worktree_departure.sh --check
```

## Dry-Run Validation

Dry-run mode validates configuration without creating worktrees, symlinks, or tmux sessions.

```bash
export SHOGUN_PATH="/path/to/shogun"
export KARO_PATHS=("/path/to/karo-1" "/path/to/karo-2")
export KARO_COUNT=1

./scripts/worktree_departure.sh --check
```

## Validation Gates

- `SHOGUN_PATH` is required and must be an existing directory
- `KARO_PATHS` is required and must be non-empty
- `KARO_COUNT` (when set) must be numeric and `<= ${#KARO_PATHS[@]}`
- No duplicate paths across Shogun and Karo
- Shogun path is a valid git repository
- Existing Karo paths are valid git worktrees
- Permissions allow writing to Shogun context and Karo parent directories

## Test Matrix

| Scenario              | Steps                                              | Expected Result                    |
| --------------------- | -------------------------------------------------- | ---------------------------------- |
| Single Karo           | `KARO_PATHS=("/path/to/karo-1")`                   | One Karo worktree, one tmux pane   |
| Multiple Karo         | `KARO_PATHS=("/path/to/karo-1" "/path/to/karo-2")` | Two Karo worktrees, two tmux panes |
| KARO_COUNT cap        | `KARO_COUNT=1` with two paths                      | One Karo worktree, one tmux pane   |
| Empty SHOGUN_PATH     | `SHOGUN_PATH=""`                                   | Fails with clear error             |
| Duplicate paths       | Same path in `KARO_PATHS` or matches `SHOGUN_PATH` | Fails with clear error             |
| Permission failure    | Parent directory not writable                      | Fails with permission error        |
| Repo mismatch warning | Karo path in different repo                        | Warning, script continues          |
| Rerun idempotence     | Run twice with same config                         | No duplicate worktrees or panes    |

## Manual Verification

After a successful run:

1. Verify symlink targets in each Karo worktree:

   ```bash
   readlink /path/to/karo-1/.agent/kingdom
   ```

2. Verify tmux session panes count matches `EFFECTIVE_KARO_COUNT`:

   ```bash
   tmux list-panes -t multi:agents
   ```

3. Confirm Copilot CLI starts in each Karo pane and uses the `karo` agent.
