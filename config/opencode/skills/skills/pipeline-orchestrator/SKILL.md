# Skill: Pipeline Orchestrator

Automate the full 5-phase agent pipeline: Planning → Ranking → Implementation → Gates → PR Review.

## When to Use

- User says "work on issue", "implement", "fix bug", "start pipeline", "run pipeline"
- User provides a GitHub issue number or description
- User says "continue pipeline" (resume from crashed session)
- User says "dispatch agents", "start council", "run gates"

## Prerequisites

- Matrix tokens at `/home/kasm-user/.config/opencode/secrets/matrix_tokens.json`
- Matrix room configured in `/home/kasm-user/.config/opencode/secrets/matrix_room.json`
- Agent config files in `~/.config/opencode/agents/` (roles.md, workflow.md, prompts.md, handoffs.md)
- Project repo at `/home/kasm-user/repot/homepilot-v2`
- `gh` CLI authenticated for `mtclab/homepilot-v2`
- Virtual env at `/home/kasm-user/repot/homepilot-v2/.venv`

## Pipeline State

State is tracked in `homepilot-v2/.opencode/state/session.json` (symlinked from `/tmp/opencode/session.json` for compatibility). On startup:
1. If session.json exists with `status: in_progress` → resume from last stage
2. If no session.json → create new session from user request
3. After each phase, update session.json atomically (write `.tmp`, then rename)

## Phase 1: Planning Council

### Auto-trigger
- User says "plan", "council", "what to work on", "prioritize"
- Pipeline starts here for new work

### Steps

1. **Generate blackboard**:
```bash
bash /home/kasm-user/.config/opencode/skills/skills/council-automation/auto-blackboard.sh "{user_request}"
```

2. **Create Matrix thread**:
```
matrix_create_thread(role='architect', topic='{issue_description}')
```
Save returned `event_id` as `thread_root` in session.json under `issues.{n}.thread_roots.council`.

3. **Choose council size** (from roles.md):
- Full (6-10): major features, architecture changes
- Standard (4-5): regular features
- Bug fix (3): targeted fixes

4. **Dispatch council agents in parallel** (use `task()`, max 10). Each agent:
- Reads blackboard at `/tmp/opencode/issues/{issue_n}/blackboard.md`
- Writes position to `/tmp/opencode/issues/{issue_n}/council/R1-{model}-{role}.md`
- Posts 1-line summary to Matrix with `thread_root`
- Uses `explore` subagent type (read-only)

5. **Wait for all agents to complete**, then read positions:
```
matrix_read(role='architect', thread_root={thread_root}, limit=20)
```
Also read council files via `glob('/tmp/opencode/issues/{issue_n}/council/R1-*.md')`.

6. **Round 2 (if needed)**: If positions diverge significantly, dispatch agents again:
- Each reads others' positions via Matrix + files
- Writes response to `R2-{model}-{role}-response.md`
- Posts challenge/agreement to Matrix

7. **Synthesize**: Write `/tmp/opencode/issues/{issue_n}/council.md` with:
- Consensus items (all agree)
- Disagreements (spectrum of positions)
- Converged decisions (numbered, actionable)
- Implementation spec
- Prioritized rollout
- Deferred items

8. **Post converged decision**:
```
matrix_post(role='architect', msg_type='converged', content='...', thread_root={thread_root})
```

9. **Create GitHub issues** from council decisions if not already existing.

10. **Update session.json**: `current_stage: "ranking"`

## Phase 2: Issue Ranking

### Steps

1. Dispatch 4-7 Coder agents in parallel (explore type)
2. Each reads all GitHub issues from Phase 1
3. Each writes ranking to `/tmp/opencode/issue-ranking/R1-{model}-rank.md`
4. Each posts 1-line summary to Matrix
5. Read rankings, synthesize into `/tmp/opencode/issue-ranking.md`
6. Update session.json: `current_stage: "implementation"`

## Phase 3: Implementation

### Pattern Selection

For each issue, determine pattern using `determine_pattern()` (see workflow.md):
```python
def determine_pattern(issue, session_state, architect_handoff):
    if architect_handoff.get('collaboration_hint'):
        return architect_handoff['collaboration_hint']
    if session_state.get('pattern_override'):
        return session_state['pattern_override']
    score = compute_complexity_score(issue, session_state)
    if score <= 2: return 'solo'
    elif score <= 4: return 'pre-emptive-reviewer'
    elif score <= 7: return 'driver-navigator'
    else: return 'ab-synthesis'
    # ... overrides and slot starvation check
```

### Solo Coder Dispatch

1. Read architect handoff + blackboard + issue description
2. Dispatch 1 Coder agent (`general` type) with full prompt from `prompts.md`
3. Include `thread_root`, `{issue_n}`, `{cycle_n}`, `{max_cycles}`
4. After Coder completes: run lint+typecheck+pytest
5. If failures: increment cycle, re-dispatch with failure context
6. If pass: update session.json, proceed to gates

### Driver/Navigator Dispatch

1. Create implementation Matrix thread
2. Dispatch Driver agent (`general` type) with Driver prompt from `prompts.md`
3. Dispatch Navigator agent (`explore` type) with Navigator prompt from `prompts.md`
4. Both use same `thread_root`
5. After Driver completes: run lint+typecheck+pytest
6. Navigator writes handoff to `{NNN}-navigator.md`
7. If failures: cycle increment, re-dispatch

### Post-Implementation Automation

After each Coder completes, **always run**:
```bash
cd /home/kasm-user/repot/homepilot-v2 && .venv/bin/ruff check . && .venv/bin/ruff format --check . && .venv/bin/mypy src/ && .venv/bin/python -m pytest {test_files} -v
```

Append results to Coder handoff under `## Lint/Typecheck/Test Results`.
Any failure → cycle += 1, re-dispatch Coder. Max 5 cycles.

## Phase 4: Gates (all parallel)

### Dispatch all 4 gates simultaneously

| Gate | Model | Role | Type |
|------|-------|------|------|
| Reviewer | kimi-k2.6 | Code review | explore |
| QA | kimi-k2.6 | Test engineer | explore |
| Security | glm-5.1 | Security auditor | explore |
| UX | glm-5.1 or qwen3.5 | UX researcher | explore |

Each reads: blackboard, Coder handoff, changed files.
Each writes: `{NNN}-{role}.md` with `## Verdict: PASS or FAIL`.
All Navigator "Deferred to Gate" items are appended to gate prompts.

### Collect verdicts

- All PASS → proceed to PR review
- Any FAIL → consolidate all failures into one Coder input, cycle += 1, re-dispatch Coder
- Max 5 gate cycles

## Phase 5: PR Review

### Steps

1. Ensure all tests pass, all gates PASS
2. Run final `ruff check . && ruff format --check . && mypy src/ && pytest`
3. Commit changes (only when user explicitly asks)
4. Push branch to remote
5. Create PR via `gh pr create`
6. Dispatch Architect + PO + PM for PR review
7. All APPROVE → merge. Any REQUEST_CHANGES → back to Coder.

## Crash Recovery

On startup, check `/tmp/opencode/session.json`:
- If `status: in_progress` and a stage has no matching live process:
  - If last handoff exists and is well-formed: resume from next stage
  - If absent or malformed: re-dispatch that stage (retry += 1)

## Scheduler Dashboard

After every dispatch and every completion, write `/tmp/opencode/scheduler.md`:
```markdown
# Scheduler — last updated {ISO8601}

| Slot | Issue | Role | Model | Cycle | Pattern | Thread root |
|------|-------|------|-------|-------|---------|-------------|
| 1    | -     | -    | -     | -     | -       | -           |
...
| 10   | -     | -    | -     | -     | -       | -           |
```

## Mandatory Matrix Communication

All Matrix communication happens IN THREADS. Never post flat messages to the room.

### Thread Lifecycle
- **Phase 1 (Planning)**: Create thread → `matrix_create_thread(role='architect', topic='issue-{n}-{description}')`
- Save `thread_root` in session.json under `issues.{n}.thread_roots.council`
- **Phase 2 (Ranking)**: Use same thread, or create ranking thread if no council thread
- **Phase 3 (Implementation)**: Create implementation thread → `matrix_create_thread(role='coder', topic='impl-{n}')`
- Save in session.json under `issues.{n}.thread_roots.implementation`
- **Phase 4 (Gates)**: Use implementation thread for gate posts
- **Phase 5 (PR Review)**: Use implementation thread

### Orchestrator Posts (always include thread_root)
- Phase start: `matrix_post(role='architect', msg_type='heads-up', content='Phase {N} starting for #{issue_n}', thread_root='{thread_root}')`
- Phase complete: `matrix_post(role='architect', msg_type='decision', content='Phase {N} complete for #{issue_n}', thread_root='{thread_root}')`
- Gate results: `matrix_post(role='architect', msg_type='converged', content='Gates: reviewer={V}, qa={V}, security={V}, ux={V}', thread_root='{thread_root}')`
- PR merged: `matrix_post(role='architect', msg_type='decision', content='PR #{pr_n} merged to dev', thread_root='{thread_root}')`

### Agent Posts (NEVER post without thread_root)
Every dispatched agent MUST:
1. Post to the issue's thread: `matrix_post(role='{role}', msg_type='position', content='...', thread_root='{thread_root}')`
2. Include the `thread_root` in their dispatch prompt
3. Gate agents MUST start with `## Verdict: PASS or FAIL`

### Thread Management Rule
- EVERY `matrix_post` call MUST include `thread_root`
- If no thread exists for an issue, create one FIRST with `matrix_create_thread`
- Store thread_root in session.json under `issues.{n}.thread_roots`
- Cross-issue coordination (ranking, sprint-level) can use a separate thread or the main room — but prefer threads

## Key Constraints

- Max 10 parallel agents (cloud capacity)
- Max 2 pair-coded issues concurrent
- Max 5 gate cycles per issue
- One issue = one branch + one commit + one PR
- Commit only when user asks
- Lint + typecheck + pytest after every Coder dispatch
- Never commit secrets
- **Every dispatch MUST include Matrix posting instructions in the agent prompt**
- **Every phase transition MUST be posted to Matrix**