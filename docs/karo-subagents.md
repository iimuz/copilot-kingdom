# Karo Subagent Patterns

Best practices and patterns for using subagents in the Karo orchestration layer.

## Overview

Karo uses the `task` tool to create on-demand subagents instead of maintaining persistent worker instances. This approach provides:

- **Resource efficiency**: Subagents created only when needed
- **Scalability**: No hard limit on concurrent workers
- **Flexibility**: Different agent types for different tasks
- **Error isolation**: Failed subagents don't affect others

## Task Tool Agent Types

### Available Agent Types

| Agent Type        | Purpose                     | Model  | Tools            | Use When                             |
| ----------------- | --------------------------- | ------ | ---------------- | ------------------------------------ |
| `explore`         | Code exploration, searching | Haiku  | grep, glob, view | Need to find code, analyze structure |
| `task`            | Command execution           | Haiku  | All CLI tools    | Running tests, builds, commands      |
| `general-purpose` | Complex multi-step work     | Sonnet | All tools        | Full implementation, refactoring     |
| `code-review`     | Code review                 | Sonnet | All tools        | Reviewing changes, PRs               |

### Agent Selection Decision Tree

```
Is the task primarily searching/exploring code?
├─ Yes → use "explore"
└─ No → Does it require running commands?
    ├─ Yes → Does it need decision-making?
    │   ├─ Yes → use "general-purpose"
    │   └─ No → use "task"
    └─ No → Is it complex multi-step work?
        ├─ Yes → use "general-purpose"
        └─ No → Handle directly (no subagent)
```

## Common Patterns

### Pattern 1: Parallel Task Execution

When Shogun delegates a task with multiple independent subtasks:

```markdown
## Example Task from Shogun

Analyze the codebase:

1. Count lines of code by language
2. Find all TODO comments
3. List all test files
4. Check for security vulnerabilities
```

**Karo's Approach**:

```
1. Parse task into subtasks
2. Launch 4 parallel subagents (agent_type="task"):
   - Subagent A: cloc analysis
   - Subagent B: grep for TODO
   - Subagent C: find test files
   - Subagent D: security scan
3. Wait for all to complete
4. Aggregate results
5. Update dashboard
```

**Implementation** (Karo's reasoning):

```
I'll use the task tool to execute these in parallel:

- cloc (A): agent_type="task", prompt="Run cloc on the codebase"
- TODO search (B): agent_type="explore", prompt="Find all TODO comments"
- Test files (C): agent_type="explore", prompt="List all test files"
- Security (D): agent_type="task", prompt="Run security vulnerability scan"
```

### Pattern 2: Sequential Pipeline

When subtasks depend on previous results:

```markdown
## Example Task from Shogun

Implement a new feature:

1. Analyze requirements
2. Design architecture
3. Implement code
4. Write tests
5. Update documentation
```

**Karo's Approach**:

```
1. Subagent A (general-purpose): Analyze requirements → produces design doc
2. Wait for A to complete
3. Subagent B (general-purpose): Implement based on design doc from A
4. Wait for B to complete
5. Subagent C (general-purpose): Write tests for implementation from B
6. Subagent D (task): Update docs based on C's tests
7. Aggregate and report
```

**Key Point**: Cannot parallelize - each step needs previous output.

### Pattern 3: Map-Reduce

When processing multiple similar items:

```markdown
## Example Task from Shogun

Refactor all API endpoints:

- /api/users
- /api/posts
- /api/comments
- /api/auth
```

**Karo's Approach**:

```
Map phase (parallel):
- Subagent A: Refactor /api/users
- Subagent B: Refactor /api/posts
- Subagent C: Refactor /api/comments
- Subagent D: Refactor /api/auth

Reduce phase:
- Aggregate common patterns
- Update shared utilities
- Create summary report
```

### Pattern 4: Explore-Then-Execute

When task requires discovery before action:

```markdown
## Example Task from Shogun

Fix all TypeScript errors in the frontend
```

**Karo's Approach**:

```
1. Subagent A (explore): Find all .ts/.tsx files with errors
   → Returns: list of 15 files with errors

2. Subagent B (general-purpose): Fix errors in batch 1 (files 1-5)
3. Subagent C (general-purpose): Fix errors in batch 2 (files 6-10)
4. Subagent D (general-purpose): Fix errors in batch 3 (files 11-15)

5. Subagent E (task): Run tsc to verify all fixed
```

### Pattern 5: Direct Handling (No Subagent)

When Karo can handle the task directly:

```markdown
## Example Task from Shogun

Update the dashboard with current status
```

**Karo's Approach**:

```
No subagent needed - this is Karo's core responsibility.
Just update dashboard.md directly.
```

**Rule**: Don't create subagents for tasks that are part of Karo's core orchestration duties.

## Error Handling Patterns

### Pattern 6: Retry with Backoff

When subagent fails temporarily:

```
1. Launch subagent A
2. A fails with transient error (network timeout)
3. Wait 5 seconds
4. Launch subagent A again with same prompt
5. If fails again, escalate to Shogun
```

### Pattern 7: Fallback Agent Type

When preferred agent type fails:

```
1. Launch subagent A (agent_type="task") for command execution
2. A fails due to insufficient capabilities
3. Launch subagent B (agent_type="general-purpose") with same task
4. B succeeds with more powerful toolset
```

### Pattern 8: Partial Success Handling

When some subagents succeed, others fail:

```
Parallel execution:
- Subagent A: Success
- Subagent B: Failed
- Subagent C: Success
- Subagent D: Failed

Actions:
1. Report successful results from A and C
2. Retry B and D once
3. If still failing, report partial completion to Shogun
4. Update dashboard with status
```

## Communication Patterns

### Pattern 9: Progress Updates

Long-running subagents should provide progress:

```
1. Launch subagent A (expected duration: 5 minutes)
2. Update dashboard: "Running code analysis..."
3. Poll subagent status every 30 seconds
4. Update dashboard with intermediate results if available
5. On completion, update with final results
```

### Pattern 10: Result Aggregation

Combining multiple subagent outputs:

```
Subagent A returns: { linesOfCode: 1000, files: 50 }
Subagent B returns: { tests: 100, coverage: 80% }
Subagent C returns: { issues: 5, warnings: 12 }

Karo aggregates:
{
  summary: "Codebase analysis complete",
  metrics: {
    linesOfCode: 1000,
    files: 50,
    tests: 100,
    coverage: "80%",
    issues: 5,
    warnings: 12
  }
}

Update dashboard with aggregated view.
```

## Anti-Patterns

### Anti-Pattern 1: Subagent for Simple Tasks

❌ **Bad**:

```
Task: "Count files in src/"
Karo: Launch subagent to run `find src/ -type f | wc -l`
```

✅ **Good**:

```
Task: "Count files in src/"
Karo: Execute directly with bash tool
```

**Rule**: If you can do it in one bash command, don't use a subagent.

### Anti-Pattern 2: Too Many Parallel Subagents

❌ **Bad**:

```
Task: Process 100 files
Karo: Launch 100 parallel subagents (one per file)
```

✅ **Good**:

```
Task: Process 100 files
Karo: Launch 5 subagents, each processing 20 files
```

**Rule**: Limit parallelism to 5-10 subagents to avoid resource exhaustion.

### Anti-Pattern 3: Nested Subagents

❌ **Bad**:

```
Karo launches subagent A
Subagent A launches subagent B (using task tool)
```

✅ **Good**:

```
Karo plans full workflow and launches all needed subagents
```

**Rule**: Subagents should not create their own subagents. Only Karo orchestrates.

### Anti-Pattern 4: Ignoring Subagent Results

❌ **Bad**:

```
Launch subagent A
Don't check result
Assume success and proceed
```

✅ **Good**:

```
Launch subagent A
Check result status
If failed, handle error appropriately
Report outcome to Shogun
```

**Rule**: Always validate subagent results before proceeding.

## Best Practices

### 1. Clear Subagent Prompts

❌ **Vague**: "Fix the code"

✅ **Clear**: "Fix TypeScript compilation errors in src/components/Button.tsx. Preserve existing functionality and add type annotations where missing."

### 2. Appropriate Agent Type Selection

Match agent capabilities to task requirements:

- **Explore**: Read-only code analysis
- **Task**: Execute specific commands, minimal decision-making
- **General-Purpose**: Complex changes requiring planning and execution

### 3. Resource Management

```
Before launching subagents:
1. Estimate number needed
2. Consider system resources
3. Batch if necessary
4. Launch in waves if >10 needed
```

### 4. Timeout Handling

```
Set reasonable timeouts:
- Explore: 1-2 minutes
- Task: 5-10 minutes (depends on command)
- General-Purpose: 10-30 minutes (depends on complexity)

If timeout exceeded:
1. Check subagent status
2. Decide: extend timeout or terminate
3. Report to Shogun if critical
```

### 5. Dashboard Updates

```
Update dashboard at key milestones:
- Before launching subagents: "Planning execution..."
- When subagents start: "Executing 5 parallel tasks..."
- On progress: "Completed 3/5 tasks..."
- On completion: "All tasks complete. Results: ..."
- On error: "Task failed: [reason]. Retrying..."
```

## Example Workflows

### Workflow 1: Code Analysis

```markdown
**Task**: Analyze Python codebase for issues

**Karo's Plan**:

1. Use explore agent to find all .py files
2. Use task agent to run flake8 linter
3. Use task agent to run mypy type checker
4. Use explore agent to find TODO/FIXME comments
5. Aggregate results
6. Update dashboard with findings

**Execution**:

- Subagent A (explore): glob pattern="\*_/_.py"
- Subagent B (task): command="flake8 ."
- Subagent C (task): command="mypy ."
- Subagent D (explore): grep pattern="TODO|FIXME"
- Aggregate and report
```

### Workflow 2: Feature Implementation

```markdown
**Task**: Add user authentication

**Karo's Plan**:

1. Analyze existing auth patterns (explore)
2. Design auth system (general-purpose)
3. Implement backend (general-purpose)
4. Implement frontend (general-purpose)
5. Write tests (general-purpose)
6. Update docs (task)

**Execution**:

- Subagent A (explore): "Analyze existing authentication patterns"
- Wait for A
- Subagent B (general-purpose): "Design JWT-based auth system"
- Wait for B
- Subagent C (general-purpose): "Implement backend auth endpoints"
- Subagent D (general-purpose): "Implement frontend login flow"
- (C and D in parallel)
- Wait for C and D
- Subagent E (general-purpose): "Write integration tests for auth"
- Wait for E
- Subagent F (task): "Update API documentation"
```

### Workflow 3: Testing Campaign

```markdown
**Task**: Run comprehensive test suite

**Karo's Plan**:

1. Run unit tests (task)
2. Run integration tests (task)
3. Run E2E tests (task)
4. Check coverage (task)
5. Aggregate results

**Execution**:

- Subagent A (task): "npm run test:unit"
- Subagent B (task): "npm run test:integration"
- Subagent C (task): "npm run test:e2e"
- (All parallel)
- Wait for all
- Subagent D (task): "npm run coverage"
- Aggregate and report pass/fail rates
```

## Debugging Subagents

### Checking Subagent Output

```bash
# View subagent execution logs
cat worktrees/karo-1/subagent-*.log

# Monitor active subagents
ps aux | grep copilot | grep task
```

### Common Issues

1. **Subagent hangs**: Set timeout, use task agent for commands
2. **Subagent fails silently**: Check error handling in prompt
3. **Subagent produces wrong result**: Refine prompt clarity
4. **Too slow**: Use faster agent type (explore vs general-purpose)

## Summary

Key principles for effective Karo subagent usage:

1. **Choose appropriate agent type** for each task
2. **Parallelize independent tasks** to maximize throughput
3. **Handle errors gracefully** with retries and fallbacks
4. **Update dashboard frequently** to keep Shogun informed
5. **Aggregate results clearly** before reporting
6. **Avoid over-engineering** - sometimes direct execution is best
7. **Resource management** - limit parallel subagents to 5-10
8. **Clear prompts** - specific, actionable, context-rich

The subagent pattern enables Karo to scale dynamically while maintaining efficient resource usage. Use it wisely to maximize system effectiveness.
