# Agent Workflow (5 Phases)

## Distrust-Downstream Pattern (Routa-inspired)

Each pipeline phase distrusts upstream output. Re-validation is mandatory, trust is earned:

1. **Ranking distrusts Planning**: Re-parse story YAML. Reject vague/missing AC. Only rank stories that are independently executable.
2. **Coder distrusts Architect**: Refuse to code if design is ambiguous or AC is missing. Request clarification before implementing.
3. **Gates distrust Coder**: Independently verify each AC. Reject self-assessment. Reject missing evidence. Reject dirty git. No partial approval.
4. **PR Review distrusts Gates**: Check AC drift. Verify gates actually tested what they claim. Reject scope creep.
5. **No stage trusts upstream verdicts at face value.** Each stage re-validates with its own evidence contract (see handoffs.md).

```
User → opencode orchestrates:

  ═══ PHASE 1: PLANNING ═══

  1. Orchestrator creates Matrix thread for planning council (matrix_create_thread).
     Dispatch up to 10 Planning agents (Architect/PO/PM variants)
     → Council size chosen per request type:
       - Full council (10): major features, architecture changes
       - Standard council (5-6): regular features
       - Bug fix council (3-4): targeted fixes
       - Infra change council (3-4): deployment/infra
     → They read the codebase
     → Each writes full position to handoff file, posts 1-line summary
       pointer to Matrix (with thread_root)
     → They read others' summaries, then read linked handoff files
     → They converge on a plan and create GitHub issues
     → Max 3 rounds, then escalate to user

  ═══ PHASE 2: RANKING ═══

  2. Orchestrator creates ranking thread. Dispatch 4-7 Coder agents in parallel
     → They read all GitHub issues from the planning phase
     → Each writes full ranking to file, posts 1-line summary to Matrix (thread_root)
     → They produce a ranked issue list with rationale
     → More models = better ranking diversity

  ═══ PHASE 3: IMPLEMENTATION ═══

  3. Dispatch Coder(s) per issue, in ranked order
     → Multiple issues can be worked IN PARALLEL (up to 3-5 issues)
     → One issue = one branch, one commit, one PR
     → Coders use Matrix MCP tools to communicate during implementation
     → Coders can ask higher-level agents via Matrix
     → auto-run lint + typecheck after each coder task
     → Optional: Pre-emptive Reviewer or Navigator alongside Coder (pair-coding)

  ═══ PHASE 4: GATES (all parallel) ═══

  4. Dispatch Reviewer + QA + Security + UX in parallel (4 gates simultaneously).
     Each reads the same coder handoff and changed files,
     writes its own handoff with Verdict: PASS|FAIL.
  5. Orchestrator collects all four verdicts:
     - All PASS → advance to PR Review
     - Any FAIL → consolidate all failures into a single coder-input
       handoff, re-dispatch Coder (cycle += 1)

  ═══ PHASE 5: PR REVIEW ═══

  6. Architect/PO/PM reviews the PR
     → Checks: design alignment, scope, acceptance criteria
     → Approve → merge
     → Request changes → back to Coder

  MAX 5 GATE CYCLES. After 5, halt and report.

  ORCHESTRATOR: Substitutes {cycle_n}, {max_cycles}, {issue_n}, {thread_root},
  and {NNN} into every prompt at dispatch time. Runs lint+typecheck+pytest
  after each Coder handoff and attaches results before gate dispatch.
```

## Planning Phase (Matrix-based deliberation)

```
1. Dispatch council agents in parallel (explore type)
   → Each reads the codebase
   → Each posts initial position to Matrix: matrix_post(role, "position", content)
   → Each writes position to /tmp/opencode/issues/{issue_n}/council/R1-{model}-{role}.md

2. Round 2 — each agent reads Matrix room, then:
   → matrix_read(role, filter_type="position", thread_root={thread_root}) to see others' summaries
   → Read linked handoff files for full positions
   → Each posts 1-line response/challenge to Matrix (with thread_root)
   → Each writes full response to /tmp/opencode/issues/{issue_n}/council/R2-{model}-{role}-response.md

3. If converged: opencode synthesizes /tmp/opencode/issues/{issue_n}/council.md
   If not: one more round (max 3 total), then escalate to user

4. Planning output → create GitHub issues from council.md decisions

Orchestrator: calls matrix_create_thread at start of planning phase; records event_id in
/tmp/opencode/issues/{issue_n}/thread_roots.json under "council".
```

## Issue Ranking Phase

(Formerly "Coder Ranking Phase". Output dir: /tmp/opencode/issue-ranking/)

```
1. Dispatch up to 7 Coder agents (explore type, parallel)
   → Each reads all GitHub issues
   → Each posts 1-line ranking summary to Matrix: matrix_post(role, "position", "ranking summary — see file", thread_root={thread_root})
   → Each writes full ranking to /tmp/opencode/issue-ranking/R1-{model}-rank.md

2. Round 2 — each reads others' rankings from Matrix
   → matrix_read(role, filter_type="position", thread_root={thread_root})
   → Read linked files for full rankings → posts agreements/challenges
   → Writes response to /tmp/opencode/issue-ranking/R2-{model}-rank-response.md

3. opencode synthesizes /tmp/opencode/issue-ranking.md:
   - Final ranked issue list
   - Dependencies between issues
   - Parallel-safe groups
```

## Implementation Phase

```
Orchestrator: calls matrix_create_thread for each issue before Coder dispatch;
records event_id in thread_roots.json under "implementation".
Updates scheduler.md on every dispatch.

With 10 slots available, multiple issues can be worked in parallel:

| Slot Pattern | Issues in flight | Agents per issue | Total slots |
|-------------|-----------------|------------------|-------------|
| Solo × 5   | 5               | 1 coder each     | 5           |
| Solo × 3 + Pair × 3 | 6        | 1-2 each        | 6-9         |
| Pair × 3 + PreReview | 3       | 3 each           | 9           |
| Solo × 10  | 10              | 1 each            | 10          |

Default: Solo × 3-5 for standard issues. Pair-coding for high-risk issues.

1. Dispatch Coder for top-ranked issue (general type)
   → Reads architect handoff + /tmp/opencode/issues/{issue_n}/blackboard.md + issue description
   → Receives {thread_root}, {issue_n}, {cycle_n}, {max_cycles} in prompt

2. During implementation, Coder can (all calls include thread_root):
   a. ASK ANOTHER CODER: matrix_post("coder", "question", "...", thread_root={thread_root})
      → matrix_read("coder", filter_type="answer", thread_root={thread_root})
   b. ASK ARCHITECT: matrix_post("coder", "question", "...", thread_root={thread_root})
      → matrix_read("architect", filter_type="answer", thread_root={thread_root})
   c. HEADS-UP: matrix_post("coder", "heads-up", "...", thread_root={thread_root})
   Max 1 round-trip per question, then decide and document.

3. Coder writes handoff. Orchestrator then runs: ruff check . && ruff format --check . && mypy src/ && pytest
   → Appends ## Lint/Typecheck/Test Results to handoff
   → Any failure: cycle += 1, re-dispatch Coder (no gate dispatch yet)
   → All pass: dispatch parallel gates

4. All Matrix messages = ephemeral. Handoff documents = permanent.

5. One issue = one branch + one commit + one PR
```

## Gate Flow

```
Standard Gate (4 reviewers): Reviewer + QA + Security + UX
Infra Gate (6 reviewers): Reviewer + QA + Security + UX + InfraOps + Integrator
Data Gate (5 reviewers): Reviewer + QA + Security + DataEngineer + UX
Full Gate (7 reviewers): Reviewer + QA + Security + UX + InfraOps + DataEngineer + Integrator

  Any FAIL → consolidate all findings into one handoff → Coder fixes → re-run all gates
  All PASS → PR Review → merge
  Max 5 cycles total, then halt and report.

Gate type is selected by orchestrator based on issue scope:
  - Bug fixes, simple features → Standard Gate (4)
  - Infra changes (Docker, PVE, Zabbix, deployment) → Infra Gate (6)
  - Data changes (schema, vault, KB, embeddings) → Data Gate (5)
  - Major cross-cutting changes → Full Gate (7)
```

## Scheduler Dashboard

Orchestrator writes `/tmp/opencode/scheduler.md` on every dispatch and every completion. Ten slots match the max-10-parallel limit. Format:

```markdown
# Scheduler — last updated {ISO8601}

| Slot | Issue | Role | Model | Cycle | Pair role | Thread root |
|------|-------|------|-------|-------|-----------|-------------|
| 1    | -     | -    | -     | -     | -         | -           |
| 2    | -     | -    | -     | -     | -         | -           |
| 3    | -     | -    | -     | -     | -         | -           |
| 4    | -     | -    | -     | -     | -         | -           |
| 5    | -     | -    | -     | -     | -         | -           |
| 6    | -     | -    | -     | -     | -         | -           |
| 7    | -     | -    | -     | -     | -         | -           |
| 8    | -     | -    | -     | -     | -         | -           |
| 9    | -     | -    | -     | -     | -         | -           |
| 10   | -     | -    | -     | -     | -         | -           |
```

Pair-coding occupies 2-3 slots. Human can `cat /tmp/opencode/scheduler.md` for live pipeline status.

## After Coder Handoff (Orchestrator Hook)

```
1. Run: ruff check . && ruff format --check . && mypy src/ && pytest
2. Append result to coder handoff under ## Lint/Typecheck/Test Results
3. Any failure → cycle += 1, fix dispatch to Coder (does not trigger gate dispatch)
4. All pass → dispatch parallel gates
```

## Pair-Coding Patterns

### Trigger Algorithm

```
def determine_pattern(issue, session_state, architect_handoff):
    # Architect override takes precedence
    if architect_handoff.get('collaboration_hint'):
        return architect_handoff['collaboration_hint']
    
    if session_state.get('pattern_override'):
        return session_state['pattern_override']
    
    # Compute complexity score
    score = 0
    files = issue.get('files_changed', [])
    if len(files) > 3: score += 2
    if len(files) > 7: score += 2
    if issue_has_labels(issue, ['auth', 'data-model', 'api', 'cross-cutting']): score += 2
    if any(p.startswith(('/auth/', '/security/', '/crypto/', '/permissions/')) for p in files): score += 1
    cycle = session_state.get('cycle', 1)
    if cycle >= 2: score += 2
    if 'pair-coding' in architect_handoff.get('risks', '').lower(): score += 1
    
    # Score → pattern
    if score <= 2: pattern = 'solo'
    elif score <= 4: pattern = 'pre-emptive-reviewer'
    elif score <= 7: pattern = 'driver-navigator'
    else: pattern = 'ab-synthesis'
    
    # Overrides
    if issue_has_labels(issue, ['frontend']) and score >= 3:
        pattern = 'driver-navigator'
    if issue_has_labels(issue, ['infra']):
        pattern = 'solo'
    if cycle >= 2 and pattern == 'solo':
        pattern = 'pre-emptive-reviewer'
    
    # Slot starvation prevention
    if pattern in ('driver-navigator', 'ab-synthesis'):
        pair_count = session_state.get('active_pair_count', 0)
        if pair_count >= 2:
            pattern = 'solo'
    
    return pattern, score
```

### Patterns (shipped in order)

| Pattern | Phase | When | Slots | Driver | Navigator/Reviewer | Challenge Bounds |
|---------|-------|------|-------|--------|--------------------|------------------|
| Solo Coder | 1 (existing) | Default, score ≤ 2 | 1 | kimi-k2.6 | — | — |
| Solo + UX | 1 (existing) | Frontend changes | 1+1 | glm-5.1 | UXResearcher (parallel) | — |
| Driver/Navigator | 1 | Score 5-7, high-risk, >3 files, security | 2 concurrent | kimi-k2.6 | deepseek-v4-flash (default), glm-5.1 (frontend), kimi-k2.6 (security) | 2/file, 5/issue |
| Pre-emptive Reviewer | 2 | Score 3-4, gate-FAIL rate >50%, cycle ≥ 2 | 2 sequential | kimi-k2.6 | deepseek-v4-flash or nemotron (after Driver+lint) | 3 total |
| A/B Synthesis | 3 | Architect explicit override only | 3+1 | kimi-k2.6 + qwen3-coder-next | kimi-k2.6 synthesizes | — |

### Pair-Coding Rules

1. **Solo is default.** 80%+ issues run solo.
2. **Navigator is advisory-only.** Driver has final authority. No vote, no consensus, no blocking.
3. **Navigator is read-only.** Never pushes commits, never modifies files. Output = handoff document.
4. **File ownership is exclusive.** Driver owns all implementation files. Orchestrator assigns ownership at dispatch.
5. **All 4 gates always run.** Navigator notes are appended to gate prompts as context, not a gate bypass.
6. **Max 2 pair-coded issues concurrent.** Hard cap to prevent slot starvation.
7. **One issue = one branch + one commit + one PR.** Pair coding doesn't change this. Driver is commit author. Navigator is Co-Authored-By.
8. **Fallback**: If pair session exceeds 1.5x estimated solo time → fall back to solo.

### Navigator Challenge Protocol

Driver posts `review-request` with files changed → Navigator reads and posts `challenge` → Driver acknowledges (accept/reject/defer). After challenge budget exhausted, Driver proceeds solo. Navigator "Deferred to Gate" items are injected into gate agent prompts.

### session.json Extensions for Pair Coding

```json
{
  "42": {
    "pattern": "solo | driver-navigator | pre-emptive-reviewer | ab-synthesis",
    "complexity_score": 6,
    "pattern_override": null,
    "pair_state": {
      "driver": {
        "model": "kimi-k2.6",
        "handoff": "002-coder.md",
        "files_owned": ["src/auth/login.py"],
        "status": "active"
      },
      "navigator": {
        "model": "deepseek-v4-flash",
        "handoff": "003-navigator.md",
        "challenges_used": 3,
        "max_challenges": 5,
        "max_challenges_per_file": 2,
        "status": "active"
      }
    },
    "slots": [
      {"slot_id": 1, "role": "driver", "model": "kimi-k2.6", "status": "active"},
      {"slot_id": 2, "role": "navigator", "model": "deepseek-v4-flash", "status": "active"}
    ]
  }
}
```

### Navigator Handoff Contract

File: `issues/{issue_n}/handoffs/{NNN}-navigator.md`

```yaml
---
pipeline_id: ...
stage: navigator
cycle: N
agent: model-name
timestamp: ISO8601
verdict: done
files_reviewed: [list]
challenges_remaining: M
---
## Challenges Raised
1. file:line — challenge text — Driver response (accept/reject/defer)

## Suggestions Accepted
- (suggestions Driver accepted)

## Suggestions Rejected
- (suggestions Driver rejected, with Driver's reason)

## Deferred to Gate
- (issues Navigator flagged but Driver deferred — MUST be addressed in gate cycle)
```

### Slot Allocation

Total budget: 10 slots. Reservation: 1 orchestrator. Usable: 9.

```
slots_free = 9 - (2 * pair_count) - (3 * synth_count) - (1 * solo_count)
```

Target: 2 pair + 5 solo = 7 issues in flight using 9 slots.

## Harness Monitor / Trace Artifacts (Routa-inspired)

Every pipeline run produces a structured trace in `/tmp/opencode/issues/{issue_n}/trace.md`. This surface answers "what happened" — traces, changed files, commands, git state, attribution. Gates and PR review read it instead of re-running everything.

### Trace Format

```markdown
# Trace — {pipeline_id} — {ISO8601}

## Run Summary
- Issue: {issue_n}
- Branch: {branch}
- Duration: {elapsed}
- Outcome: pass | fail | blocked

## Stage History
| Stage | Agent | Model | Cycle | Verdict | Timestamp | Handoff |
|-------|-------|-------|-------|---------|-----------|---------|
| architect | architect-1 | kimi-k2.6 | 1 | done | ... | 001-architect.md |
| coder | coder-1 | kimi-k2.6 | 1 | done | ... | 002-coder.md |
| reviewer | reviewer-1 | deepseek-v4-flash | 1 | pass | ... | 003-reviewer.md |
| ... | ... | ... | ... | ... | ... | ... |

## Files Changed
| File | Stage | Agent | Lines +/- |
|------|-------|-------|-----------|
| src/auth/login.py | coder | kimi-k2.6 | +45/-12 |
| tests/test_login.py | coder | kimi-k2.6 | +60/-0 |

## Commands Run
| Command | Stage | Result |
|---------|-------|--------|
| ruff check . | post-coder | clean |
| pytest tests/test_login.py | post-coder | 3/3 passed |

## Git State at Each Stage
| Stage | Commit | Dirty | Branch |
|-------|--------|-------|--------|
| post-coder | abc1234 | no | feat/short-desc |
| post-gate | abc1234 | no | feat/short-desc |

## Acceptance Criteria Tracking
| AC# | Description | Coder Status | Reviewer | QA | PR Review |
|-----|-------------|-------------|----------|-------|-----------|
| AC-1 | User can log in | done | PASS | PASS | — |
| AC-2 | Session persists | done | PASS | PASS | — |
| AC-3 | Rate limiting works | partial | FAIL | FAIL | — |
```

### Who Writes Trace

- **Orchestrator** writes initial trace after each Coder completes (appends stage history, files changed, commands, git state).
- **Gates** append their verdicts to the AC tracking table.
- **PR Review** reads the full trace to verify no AC drift and all evidence is present.
- Trace is append-only. Never overwrite — only append new sections.

### Fitness Checks (Routa-inspired)

Before a handoff advances to the next stage, three layered checks run:

1. **Harness Check** (what happened): trace exists, handoff file is well-formed, frontmatter parses, evidence sections present.
2. **Fitness Check** (what should be true): AC coverage = 100%, lint/typecheck clean, no uncommitted changes, file budget within limits (default: max 15 files changed per issue).
3. **Gate Check** (can it advance): all ACs have evidence, all gate verdicts are PASS, no deferred items unresolved.

If any check fails, the handoff is rejected and the agent is re-dispatched with the specific failure reason.