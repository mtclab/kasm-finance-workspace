# Skill: Implementation Dispatch

Automate Phase 3 of the pipeline: dispatch Coder agents with pattern selection (Solo, Driver/Navigator, Pre-emptive Reviewer, A/B Synthesis).

## When to Use

- After planning council converges and issues are ranked
- After issue is assigned and blackboard is ready
- User says "implement", "code this", "start coding"
- Pipeline reaches Phase 3 automatically

## Prerequisites

- Council decisions at `homepilot-v2/.opencode/state/issues/{issue_n}/council.md` (symlinked via `/tmp/opencode/`)
- Blackboard at `homepilot-v2/.opencode/state/issues/{issue_n}/blackboard.md`
- session.json with `current_stage: "implementation"`
- Git branch created for the issue

## Step 1: Determine Implementation Pattern

Read the council decisions and architect handoff for `collaboration_hint`. If none, compute complexity score:

```python
score = 0
files = issue.get('files_changed', [])

if len(files) > 3: score += 2
if len(files) > 7: score += 2
if has_labels(issue, ['auth', 'data-model', 'api', 'cross-cutting']): score += 2
if any(p.startswith(('/auth/', '/security/', '/crypto/', '/permissions/')) for p in files): score += 1
cycle = session_state.get('cycle', 1)
if cycle >= 2: score += 2
if 'pair-coding' in architect_handoff.get('risks', '').lower(): score += 1
if any('requirements' in f or 'package.json' in f for f in files): score += 1

# Score → pattern
if score <= 2: pattern = 'solo'
elif score <= 4: pattern = 'pre-emptive-reviewer'
elif score <= 7: pattern = 'driver-navigator'
else: pattern = 'ab-synthesis'

# Overrides
if has_labels(issue, ['frontend']) and score >= 3: pattern = 'driver-navigator'
if has_labels(issue, ['infra']): pattern = 'solo'
if cycle >= 2 and pattern == 'solo': pattern = 'pre-emptive-reviewer'
if pair_count >= 2: pattern = 'solo'  # slot starvation
```

## Step 2: Create Issue Infrastructure

```bash
mkdir -p homepilot-v2/.opencode/state/issues/{issue_n}/council
mkdir -p homepilot-v2/.opencode/state/issues/{issue_n}/handoffs
mkdir -p homepilot-v2/.opencode/state/issues/{issue_n}/coder-council
```

Create or update `homepilot-v2/.opencode/state/session.json` (symlinked from `/tmp/opencode/session.json`) with pattern, complexity_score, pair_state.

## Step 3: Dispatch Based on Pattern

### Solo Coder (default)

1 Coder agent, `general` type (needs write access):

```
task(
  subagent_type="general",
  description="Implement issue #{issue_n}",
  prompt="""
  [CYCLE {cycle_n} of {max_cycles}]
  
  You are the implementation squad. Write clean, minimal code.
  
  Read /tmp/opencode/issues/{issue_n}/blackboard.md and prior handoffs for context.
  Read the architect handoff at /tmp/opencode/issues/{issue_n}/handoffs/{architect_handoff}.
  
  [Gate input if cycle > 1: previous gate failures]
  
  MCP tools: Matrix MCP + Context7 MCP
  
  Write handoff to /tmp/opencode/issues/{issue_n}/handoffs/{NNN}-coder.md.
  Body: ## Files Changed, ## Implementation Notes, ## Manual Testing Checklist.
  Append notes to blackboard.md under ## [Coder].
  """
)
```

After Coder completes:
```bash
cd /home/kasm-user/repot/homepilot-v2
.venv/bin/ruff check . && .venv/bin/ruff format --check . && .venv/bin/mypy src/ && .venv/bin/python -m pytest {test_files} -v
```

If failures → cycle += 1, include failure output in Coder re-dispatch.

### Driver/Navigator (2 slots, concurrent)

Create implementation Matrix thread:
```
matrix_create_thread(role='coder', topic='implementation-{issue_n}')
```

Dispatch both in parallel:

**Driver** (`general` type — writes code):
```
[Full Driver prompt from prompts.md with thread_root, issue_n, cycle_n]
```

**Navigator** (`explore` type — read-only):
```
[Full Navigator prompt from prompts.md with thread_root, issue_n]
```

Navigator reads `heads-up` messages from Driver, posts `challenge` messages (bounded: 2/file, 5/issue).

After Driver completes: run lint+typecheck+tests. Navigator writes separate handoff.

### Pre-emptive Reviewer (2 slots, sequential)

1. Dispatch Driver (`general` type) solo
2. After Driver completes + lint/typecheck pass:
3. Dispatch Pre-reviewer (`explore` type) to review Driver's work
4. Pre-reviewer writes handoff with `## Verdict: PASS/FAIL`
5. If FAIL: feed findings back to Driver, cycle += 1
6. If PASS: proceed to formal gates

### A/B Synthesis (3+1 slots)

1. Create issue branches: `feat/{issue-slug}-a` and `feat/{issue-slug}-b`
2. Dispatch Coder-A on branch A (`general` type)
3. Dispatch Coder-B on branch B (`general` type, different approach)
4. Both work independently, no coordination
5. After both complete: Dispatch Synthesizer (`general` type, model=kimi-k2.6)
6. Synthesizer reads both handoffs, merges best of both, creates `feat/{issue-slug}` branch
7. Clean up approach branches

## Step 4: Pattern-Specific session.json Updates

### Solo
```json
{
  "pattern": "solo",
  "complexity_score": 2,
  "slots": [
    {"slot_id": 1, "role": "coder", "model": "kimi-k2.6", "status": "active"}
  ]
}
```

### Driver/Navigator
```json
{
  "pattern": "driver-navigator",
  "complexity_score": 6,
  "pair_state": {
    "driver": {"model": "kimi-k2.6", "handoff": "002-coder.md", "files_owned": ["..."], "status": "active"},
    "navigator": {"model": "deepseek-v4-flash", "handoff": "003-navigator.md", "challenges_used": 0, "max_challenges": 5, "status": "active"}
  },
  "slots": [
    {"slot_id": 1, "role": "driver", "model": "kimi-k2.6", "status": "active"},
    {"slot_id": 2, "role": "navigator", "model": "deepseek-v4-flash", "status": "active"}
  ]
}
```

### Pre-emptive Reviewer
```json
{
  "pattern": "pre-emptive-reviewer",
  "complexity_score": 4,
  "slots": [
    {"slot_id": 1, "role": "driver", "model": "kimi-k2.6", "status": "completed"},
    {"slot_id": 2, "role": "prereviewer", "model": "deepseek-v4-flash", "status": "active"}
  ]
}
```

## Step 5: Post-Implementation

After Coder completes and tests pass:
1. Append lint/typecheck/test results to Coder handoff
2. Update session.json: `coder: {status: "done"}`
3. Set `current_stage: "gates"`
4. Trigger gate-dispatch skill

## Navigator Challenge Enforcement

The orchestrator (not the agent) enforces challenge bounds:
- Track `challenges_used` in pair_state
- If `challenges_used >= max_challenges` (5): Navigator dispatch skips challenge prompt
- If `challenges_used >= max_challenges_per_file` (2) for any file: Navigator told to skip that file

## Key Constraints

- Max 2 pair-coded issues concurrent (slot starvation prevention)
- One issue = one branch + one commit + one PR
- Navigator is read-only (explore type)
- Driver has final authority on all decisions
- Fallback: if pair session > 1.5x solo estimate → switch to solo
- Lint + typecheck + pytest after every Coder dispatch

## Mandatory Matrix Communication

All Matrix communication happens IN THREADS. Never post flat messages to the room.

Every dispatched agent MUST include this block in their prompt:

```
## Matrix Communication (MANDATORY — ALL POSTS IN THREAD)

You MUST post to Matrix after completing your work. ALL posts go in the issue thread.

Thread root: {thread_root}
Your role: {role}

Required posts:
1. On start: matrix_post(role='{role}', msg_type='heads-up', content='Starting implementation for #{issue_n}', thread_root='{thread_root}')
2. On completion: matrix_post(role='{role}', msg_type='position', content='1-line summary — see handoff file', thread_root='{thread_root}')
3. On issues found: matrix_post(role='{role}', msg_type='challenge', content='FINDING-N: [severity] description', thread_root='{thread_root}')
4. On done: matrix_post(role='{role}', msg_type='decision', content='Implementation complete. {N} files changed. Handoff: {path}', thread_root='{thread_root}')

NEVER post without thread_root. If you need to post and don't have thread_root, create a thread first with matrix_create_thread(role='architect', topic='issue-{n}-{desc}').

Room: !9PnzYFd37ezepO_4f8lzeSjhzSXuP-JO8ZoJjI5znHU
```

The orchestrator MUST also post (always with thread_root):
- Before dispatch: `matrix_post(role='architect', msg_type='heads-up', content='Dispatching {pattern} for #{issue_n} cycle {n}', thread_root='{thread_root}')`
- After dispatch completes: `matrix_post(role='architect', msg_type='converged', content='#{issue_n} cycle {n} complete. Lint:PASS Typecheck:PASS Tests:PASS', thread_root='{thread_root}')`