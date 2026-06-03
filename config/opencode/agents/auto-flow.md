# Automated Pipeline Protocol

## Principle

When the user says "let the orchestra handle it" or "fix everything" or any request that triggers the full pipeline, the orchestrator MUST execute ALL phases automatically without stopping for user confirmation between phases. The pipeline only stops when:
- All gates PASS and PRs are merged
- A gate FAILs after 5 cycles
- The user explicitly says "stop" or "pause"

## Auto-Flow Rules

### Phase Transitions (automatic, no user input needed)

1. **Planning → Ranking**: After council converges and blackboard is written, immediately create ranking thread and dispatch ranking agents. No pause.

2. **Ranking → Implementation**: After rankings are synthesized into a prioritized issue list, immediately create implementation threads and dispatch coders for top-ranked issues. No pause.

3. **Implementation → Gates (all 4 in parallel)**: After each coder finishes and lint/typecheck/test pass, immediately dispatch Reviewer + QA + Security + UX in parallel. No pause.

4. **Gate cycle (FAIL → Coder)**: If any gate FAILs, consolidate all failures into one handoff, re-dispatch Coder (cycle += 1). No pause. Max 5 cycles.

5. **Gate cycle (all PASS) → PR Review**: If all 4 gates PASS, immediately create PR. No pause.

6. **PR Review → Merge**: After architect/PO/PM review, merge if approved. If changes requested, re-dispatch Coder. No pause.

7. **Merge → Next Issue**: If multiple issues ranked, start next one immediately. No pause.

### What requires user input (ONLY these)

- Creating GitHub issues from council decisions (if council identifies issues not in the original request)
- Approving scope changes that exceed the original request
- Handling 5-cycle gate failures (escalation to user)

### What does NOT require user input

- Dispatching council agents
- Dispatching coders
- Dispatching gate reviewers
- Reading gate verdicts
- Re-dispatching coders on FAIL
- Creating PRs
- Merging PRs after all gates PASS
- Moving to next issue
- Updating scheduler.md

## Thread Enforcement

### MANDATORY: Every Matrix MCP call MUST include thread_root

All `matrix_post` and `matrix_read` calls MUST include `thread_root`. This is not optional. If an agent posts without `thread_root`, the message goes to the room instead of the thread, making it invisible to other agents.

### When to use threads vs room

| Phase | Thread created? | Thread root used for |
|-------|----------------|---------------------|
| Planning (council) | YES — by orchestrator | ALL council deliberation |
| Ranking | YES — by orchestrator | ALL ranking messages |
| Implementation (per issue) | YES — by orchestrator | ALL coder and navigator messages for that issue |
| Gates (per issue) | YES — by orchestrator | ALL gate review messages for that issue |
| PR Review | YES — by orchestrator | ALL PR review messages |

### Thread enforcement in agent prompts

Every agent dispatch prompt MUST include:
1. The `thread_root` parameter with the actual event ID
2. An explicit instruction: "You MUST pass thread_root={thread_root} in every matrix_post and matrix_read call. Messages without thread_root go to the room instead of the thread and will be invisible to other agents."

### Orchestrator responsibilities

1. Create thread at start of each phase (matrix_create_thread)
2. Store thread_root in /tmp/opencode/issues/{issue_n}/thread_roots.json
3. Include thread_root in EVERY agent dispatch prompt
4. After each phase, check Matrix for any messages posted to the room (not thread) and repost them to the thread

## Scheduler Updates

After every dispatch and every completion, update `/tmp/opencode/scheduler.md` with:
- Current slot assignments
- Phase currently in
- Issue being worked on
- Cycle number
- Any blockers

## Issue Tracking

After planning creates GitHub issues:
- Store issue numbers in /tmp/opencode/issues/{issue_n}/issue.json
- Reference issue numbers in all subsequent phases
- Include issue numbers in PR titles and descriptions