# Handoff Documents & Infrastructure

## Infrastructure

```
/tmp/opencode/
├── blackboard.md             # Cross-issue context (daily-rotated — see Blackboard Lifecycle)
├── scheduler.md              # Live slot status (orchestrator writes on every dispatch)
├── session.json              # Multi-issue pipeline state machine (orchestrator writes)
└── issues/
    └── {issue_n}/            # One directory per GitHub issue
        ├── blackboard.md     # Per-issue append-only context
        ├── council/          # Planning council positions for this issue
        │   ├── R1-deepseek-architect.md
        │   ├── R1-glm-po.md
        │   └── ...
        ├── coder-council/    # Implementation deliberation for this issue
        │   └── R1-{model}-coder.md
        ├── handoffs/         # Per-agent handoffs (NNN resets per issue)
        │   ├── 001-architect.md
        │   ├── 002-coder.md
        │   ├── 003-reviewer.md
        │   └── ...
        └── thread_roots.json # {phase: matrix_event_id} populated by orchestrator

/tmp/opencode/pre-issue/      # Artifacts before GitHub issues are filed
    └── council/              # Moved into issues/{n}/ once issues are created

/tmp/opencode/issue-ranking/  # Issue prioritization (was: coder-rank/)
    └── R1-{model}-rank.md
```

Secrets: `/home/kasm-user/.config/opencode/secrets/` — NEVER commit

## Universal Frontmatter

```yaml
---
pipeline_id: short-desc-date
stage: planning | ranking | architect | coder | navigator | prereviewer | reviewer | qa | security | devops | infraops | dataengineer | integrator | ux | pr-review
cycle: N
agent: model-name
timestamp: ISO8601
verdict: done | blocked | pass | fail | approve | request_changes
files_read: [list]
files_modified: [list]
files_created: [list]
issues_found: [list]  # reviewer/qa/security only
---
```

## Evidence Contracts (Routa-inspired)

Each pipeline stage MUST produce evidence that the next stage can verify independently. Evidence accumulates per handoff — the same issue grows stricter as it advances. Downstream stages DISTRUST upstream output and re-validate.

| Stage | Evidence Required | Downstream Validates |
|-------|-------------------|---------------------|
| Planning | Canonical story YAML: problem, acceptance criteria, constraints, dependencies, INVEST check | Ranking re-parses YAML, rejects weak stories |
| Architect | Design decisions + API/data contract + risk assessment | Coder checks design is implementable, refuses to code if ambiguous |
| Coder | Dev evidence: changed files, tests run, per-AC verification, lint/typecheck clean | Reviewer independently checks each AC, rejects missing evidence |
| Reviewer/QA/Security/UX | Per-AC verdict + issues + findings | Orchestrator rejects partial approval — all must PASS or all retry |
| PR Review | Alignment score + merged diff review | Reject if scope creep or AC drift |

**Key rule**: A handoff without the required evidence section is MALFORMED. Re-dispatch with "fix handoff — missing {evidence}" (retry += 1).

## Per-Role Body Contracts

**Architect** MUST include:
- `## Design Decisions` — numbered, with rationale
- `## API Contract` or `## Data Model Contract`
- `## Integration Points`
- `## Risks`
- `## Acceptance Criteria` — numbered list, each independently verifiable (evidence contract)

**Coder** MUST include:
- `## Files Changed` — every file modified with summary
- `## Implementation Notes` — deviations from design
- `## Manual Testing Checklist`
- `## Per-AC Evidence` — for each acceptance criterion: status (done/partial/blocked), how verified, test command output
- `## Lint/Typecheck Results` — must be clean or explicitly explain remaining warnings

**Reviewer** MUST start with:
- `## Verdict: PASS` or `## Verdict: FAIL`
- `## Per-AC Status` — for each AC: PASS/FAIL + evidence checked
- Issues: `file:line — problem — suggested fix`
- **No partial approval** — if any AC is FAIL, verdict is FAIL

**QA** MUST start with:
- `## Verdict: PASS` or `## Verdict: FAIL`
- `## Per-AC Status` — for each AC: verified/unverified + how
- `## Test Results` — pass/fail counts
- `## Test Files` — paths
- `## Failures` — detailed output

**Security** MUST start with:
- `## Verdict: PASS` or `## Verdict: FAIL`
- Findings: `FINDING-{N}, severity, file:line, description, fix`

**PR Review (Architect/PO/PM)** MUST start with:
- `## Verdict: APPROVE` or `## Verdict: REQUEST_CHANGES`
- `## Alignment` — how well PR matches planning decisions + AC coverage
- `## AC Drift` — any acceptance criteria modified/skipped without planning approval
- `## Issues` — changes requested (if any)

**DevOps** MUST include:
- `## Infrastructure Changes`
- `## Verification Steps`
- `## Rollback Plan`

**InfraOps** MUST include:
- `## Infra Changes` — VMs, containers, networks, storage modified
- `## Verification Steps` — health checks, connectivity tests
- `## Rollback Plan` — how to undo

**DataEngineer** MUST include:
- `## Schema Changes` — tables, columns, indexes added/modified
- `## Migration Steps` — numbered steps to apply
- `## Data Integrity Checks` — how to verify data is correct
- `## Rollback Plan`

**Integrator** MUST include:
- `## Integration Points` — what connects to what
- `## API Contracts` — endpoints, payloads, auth
- `## Verification Steps` — end-to-end test procedure
- `## Rollback Plan`

## Scheduler Slots

With 10 parallel slots available (cloud capacity), the scheduler tracks all 10. See workflow.md for the full scheduler format. Key allocation patterns:

| Phase | Typical slot allocation | Notes |
|-------|------------------------|-------|
| Planning council | 5-10 slots | All council members in parallel |
| Issue ranking | 4-7 slots | All ranking coders in parallel |
| Implementation (solo) | 1 slot per issue | Up to 10 issues simultaneously |
| Implementation (pair) | 2-3 slots per issue | Driver + Navigator or A/B |
| Gates | 4 slots | Reviewer + QA + Security + UX, all parallel |
| PR Review | 2-3 slots | Architect + PO + PM |

## Naming Convention

```
issues/{issue_n}/council/R{N}-{model}-{role}[-response].md
issues/{issue_n}/coder-council/R{N}-{model}-coder[-response].md
issues/{issue_n}/handoffs/{NNN}-{role}[-cycle{M}].md
issue-ranking/R{N}-{model}-rank[-response].md
pre-issue/council/R{N}-{model}-{role}[-response].md  # before GitHub issue exists
```

Sequence numbers (`NNN`) reset per issue — `001` always means the first handoff for that issue.
Globally-unique naming not needed; `{issue_n}` provides the namespace.

## Navigator Handoff Contract

```yaml
---
pipeline_id: short-desc-date
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

## Pre-reviewer Handoff Contract

```yaml
---
pipeline_id: short-desc-date
stage: prereviewer
cycle: N
agent: model-name
timestamp: ISO8601
verdict: pass | fail
files_reviewed: [list]
---
## Verdict: PASS or FAIL
## Findings
- file:line — issue — suggested fix
```

## Failure Modes

| Failure | Response |
|---------|----------|
| Agent skips handoff | Re-dispatch with explicit reminder (retry counter += 1) |
| Agent writes malformed YAML | Re-dispatch with "fix frontmatter" (retry counter += 1) |
| Gate verdict ambiguous | Ask user |
| Parallel Coders conflict on same file | Single Coder resolves merge |
| 5 cycles exhausted | Halt, report all handoffs to user |
| Multiple gates FAIL same cycle | Single consolidated coder handoff; coder addresses all in next cycle |

## Retry Policy

Each stage in `session.json` tracks `retries` and `max_retries` (default 3):

```json
"stages": {
  "coder": { "status": "active", "handoff": ["..."], "retries": 0, "max_retries": 3 }
}
```

On agent failure (skipped handoff, malformed YAML, timeout), orchestrator increments `retries` and re-dispatches with an explicit reminder. On `retries == max_retries`, escalate to user with all attempted handoffs.

**Distinct from gate-cycle counter** — retries count agent execution failures; gate cycles count PASS/FAIL verdict iterations.

## Crash Recovery

- Orchestrator writes `session.json.tmp` then renames atomically over `session.json`. Never partial writes.
- On startup, if `session.json` shows an in-progress stage with no matching live process:
  - If last handoff for that stage is present and well-formed: resume from next stage.
  - If absent or malformed: re-dispatch the in-progress stage (retry counter += 1).

## Blackboard Lifecycle

- `/tmp/opencode/blackboard.md` — cross-issue context, rotated daily by orchestrator: at first dispatch of a new calendar date, rename current file to `blackboard-{YYYY-MM-DD}.md` and start fresh.
- `/tmp/opencode/issues/{n}/blackboard.md` — per-issue, append-only for the lifetime of the issue. Archived to `/tmp/opencode/issues/archive/{n}/` after PR merge.

## session.json Schema

```json
{
  "pipeline_id": "short-desc-date",
  "user_request": "original user request",
  "status": "in_progress | done | failed",
  "active_issues": [42, 43],
  "issues": {
    "42": {
      "current_stage": "coder",
      "cycle": 1,
      "max_cycles": 5,
      "thread_roots": {"council": "...", "implementation": "...", "gates-c1": "..."},
      "stages": {
        "architect": { "status": "done", "handoff": "001-architect.md", "retries": 0, "max_retries": 3 },
        "coder":     { "status": "active", "handoff": ["002-coder.md"], "retries": 0, "max_retries": 3 },
        "reviewer":  { "status": "pending", "retries": 0, "max_retries": 3 },
        "qa":        { "status": "pending", "retries": 0, "max_retries": 3 },
        "security":  { "status": "pending", "retries": 0, "max_retries": 3 }
      },
      "branch": "feat/short-desc",
      "files_changed": ["path/to/file.py"],
      "gate_results": { "review": null, "qa": null, "security": null }
    }
  }
}
```