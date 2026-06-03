# Skill: Gate Dispatch

Automate Phase 4 of the pipeline: dispatch Reviewer + QA + Security + UX in parallel, collect verdicts, handle failures.

## When to Use

- After Coder completes implementation and lint/typecheck/tests pass
- User says "run gates", "gate review", "review the code"
- Pipeline reaches Phase 4 automatically

## Prerequisites

- Coder handoff exists at `/tmp/opencode/issues/{issue_n}/handoffs/{NNN}-coder.md`
- Lint + typecheck + pytest all pass
- session.json shows `current_stage: "gates"` or `coder: done`

## Steps

### 1. Verify Coder Output

Before dispatching gates, verify:
```bash
cd /home/kasm-user/repot/homepilot-v2
.venv/bin/ruff check .
.venv/bin/ruff format --check .
.venv/bin/mypy src/
.venv/bin/python -m pytest {relevant_test_files} -v
```

If any fail → do NOT dispatch gates. Re-dispatch Coder with failure context.

### 2. Read Context

Read these files to build gate agent prompts:
- `/tmp/opencode/issues/{issue_n}/blackboard.md`
- `/tmp/opencode/issues/{issue_n}/handoffs/{NNN}-coder.md` (Coder handoff)
- `/tmp/opencode/issues/{issue_n}/handoffs/{NNN}-navigator.md` (if exists, for pair-coded issues)
- Git diff of changed files (from `git diff` or `git diff main...HEAD`)

### 3. Build Navigator Context (if applicable)

If the issue used Driver/Navigator pattern:
- Append Navigator's "Deferred to Gate" items to each gate agent's prompt
- These were flagged but not fixed by the Driver — gates MUST address them

### 4. Dispatch All 4 Gates in Parallel

Use `task()` with `explore` subagent type (read-only — gates don't write code).

| Gate | Model | Prompt Key Points |
|------|-------|-------------------|
| Reviewer | kimi-k2.6 | Code review: bugs, style, error handling, architectural drift. Use Context7 for framework best practices. Must start with `## Verdict: PASS/FAIL`. |
| QA | kimi-k2.6 | Test engineering: coverage gaps, edge cases, run tests, report failures. Use Context7 for testing patterns. Must start with `## Verdict: PASS/FAIL`. |
| Security | glm-5.1 | Security audit: hardcoded secrets, injection, SSRF, auth bypass. Must start with `## Verdict: PASS/FAIL`. Each finding: FINDING-{N}, severity, file:line. |
| UX | glm-5.1 or qwen3.5 | Usability, accessibility (WCAG 2.1), user-facing friction. For backend: API usability. Must include severity ratings and recommendations. |

### 5. Gate Prompt Template

Each gate agent receives:
- The full changes (git diff or file paths)
- The Coder handoff document
- Navigator "Deferred to Gate" items (if any)
- The blackboard context
- The council decisions (if applicable)
- Their specific role prompt from `~/.config/opencode/agents/prompts.md`

### 6. Collect Verdicts

Read each handoff file:
- `/tmp/opencode/issues/{issue_n}/handoffs/{NNN}-reviewer.md`
- `/tmp/opencode/issues/{issue_n}/handoffs/{NNN}-qa.md`
- `/tmp/opencode/issues/{issue_n}/handoffs/{NNN}-security.md`
- `/tmp/opencode/issues/{issue_n}/handoffs/{NNN}-ux.md`

Parse each for `## Verdict:` line.

### 7. Decision Matrix

| Verdict Combination | Action |
|---------------------|--------|
| All PASS | Advance to Phase 5 (PR Review) |
| Any FAIL | Consolidate ALL findings into one Coder input handoff. Increment cycle. Re-dispatch Coder. |
| Ambiguous verdict | Ask user |

### 8. Failure Consolidation

When gates FAIL, write a consolidated Coder input:
```markdown
# Gate Failures — Cycle {cycle_n}

## Reviewer Findings
[All FAIL items from reviewer handoff]

## QA Findings
[All FAIL items from QA handoff]

## Security Findings
[All FAIL items from security handoff]

## UX Findings
[All FAIL items from UX handoff]

## Required Fixes
[Numbered list of all required fixes]
```

Save as `/tmp/opencode/issues/{issue_n}/handoffs/{NNN+1}-gate-input.md`

### 9. Re-dispatch Coder

If gates FAIL:
- cycle += 1
- If cycle > 5: halt and report all handoffs to user
- Re-dispatch Coder with gate input + original blackboard
- After Coder completes: run lint/typecheck/tests, then dispatch gates again

### 10. Update Session State

After each gate cycle, update `/tmp/opencode/session.json`:
```json
{
  "issues": {
    "{n}": {
      "stages": {
        "reviewer": {"status": "pass|fail", "handoff": "002-reviewer.md"},
        "qa": {"status": "pass|fail", "handoff": "002-qa.md"},
        "security": {"status": "pass|fail", "handoff": "002-security.md"},
        "ux": {"status": "pass|fail", "handoff": "002-ux.md"}
      },
      "gate_results": {
        "review": "pass",
        "qa": "fail — 2 test gaps",
        "security": "pass",
        "ux": "pass"
      }
    }
  }
}
```

## Key Constraints

- All 4 gates MUST run in parallel, never sequentially
- Navigator notes are context for gates, not a gate bypass
- Max 5 gate cycles before halting
- Gate agents are `explore` type (read-only)
- Always append Navigator "Deferred to Gate" items to gate prompts

## Mandatory Matrix Communication (IN THREADS)

All gate posts go in the issue's implementation thread. Never post flat to the room.

Before dispatching gates:
```
matrix_post(role='architect', msg_type='heads-up', content='Running gates cycle {n} for #{issue_n}', thread_root='{thread_root}')
```

Each gate agent prompt MUST include:
```
## Matrix Communication (MANDATORY — IN THREAD)

After completing your review, post your verdict to Matrix IN THE THREAD:
matrix_post(role='{role}', msg_type='position', content='## Verdict: PASS or FAIL — {1-line summary}', thread_root='{thread_root}')

Thread root: {thread_root}
Room: !9PnzYFd37ezepO_4f8lzeSjhzSXuP-JO8ZoJjI5znHU
```

After collecting all gate verdicts:
```
matrix_post(role='architect', msg_type='converged', content='Gates cycle {n}: reviewer={V}, qa={V}, security={V}, ux={V}', thread_root='{thread_root}')
```