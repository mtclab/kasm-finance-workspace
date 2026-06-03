---
name: inter-agent-messaging
description: "Send direct messages between agents. Planning agents DM to debate and converge on plans. Coder agents DM to rank issues, help each other during implementation, and ask higher-level agents for guidance. Triggers: agent needs clarification, architect wants to warn coder, planning debate, coder ranking, cross-level guidance."
version: 2.0.0
author: homepilot
triggers:
  - "message between agents"
  - "ask another agent"
  - "clarification from architect"
  - "challenge assumption"
  - "heads-up for coder"
  - "direct message agent"
  - "agent question"
  - "quick question for"
  - "planning debate"
  - "coder ranking"
  - "cross-level guidance"
  - "coder help"
---

# Inter-Agent Messaging

## When to Use

| Situation | Mode |
|-----------|------|
| Planning agents debating approach | DM (planning phase) |
| Coders ranking issues | DM (ranking phase) |
| Coder asking another Coder for help | DM (implementation) |
| Coder asking Architect for guidance | DM (cross-level) |
| Gate PASS/FAIL decision | Handoff document |
| Files changed report | Handoff document |
| PR review verdict | Handoff document |
| 3+ rounds without convergence | Escalate to user |

## When NOT to Use

- Gate decisions (Reviewer/QA/Security PASS/FAIL) → use handoffs
- Permanent record keeping → use handoffs or blackboard
- Skipping pipeline stages → never allowed

## Message Format

File: `/tmp/opencode/messages/{from}-{to}-{seq}.md`

```yaml
---
from: {agent-role-model}    # e.g. deepseek-architect
to: {agent-role-model}      # e.g. glm-coder
timestamp: ISO8601
thread: {thread-id}          # optional — groups related messages
type: question | answer | challenge | clarification | heads-up | decision
priority: low | normal | high
---
```

Body: freeform markdown. Caveman comms. Short and direct.

## Thread Format

Directory: `/tmp/opencode/messages/threads/{thread-id}/`
Metadata: `/tmp/opencode/messages/threads/{thread-id}.json`

```json
{
  "thread_id": "drift-verify-concurrency",
  "participants": ["deepseek-architect", "glm-coder"],
  "started_at": "ISO8601",
  "status": "open | resolved | escalated",
  "resolution": null,
  "message_count": 3
}
```

## Message Types

| Type | Purpose |
|------|---------|
| `question` | Ask another agent something |
| `answer` | Respond to a question |
| `challenge` | Push back on an assumption |
| `clarification` | Ask for more detail |
| `heads-up` | FYI without expecting response |
| `decision` | State a resolved decision |

## Cross-Level DMs (Coder → Architect/PO/PM)

Coders can DM higher-level agents when they need guidance:
- Implementation diverges from design → DM Architect
- Scope uncertainty → DM PO
- Dependency conflict → DM PM
- Max 1 round-trip per question, then Coder makes a decision and documents it

Examples:
```
Coder → Architect: "DB schema doesn't match API contract — which takes priority?"
Architect → Coder: "API contract wins. Add a migration in the next PR."

Coder → PO: "The drift refresh endpoint works, but should we also add WebSocket push?"
PO → Coder: "No — out of scope for this sprint. Open a backlog issue if needed."

Coder → Another Coder: "How does the ArtifactStore handle concurrent writes?"
Other Coder → Coder: "It uses file locks via fcntl. Check store.py:142."
```

## Flow

```
1. Agent A executes, needs input from Agent B
2. Agent A writes message to /tmp/opencode/messages/
3. Agent A returns — task output says "waiting on reply from {agent}"
4. opencode dispatches Agent B with message as context + instruction to respond
5. Agent B writes reply to /tmp/opencode/messages/
6. opencode re-dispatches Agent A (resume via task_id) with reply
7. Agent A continues with new information
```

## Constraints

- **Max 3 messages per thread** — if agents can't converge in 3 exchanges, escalate to user
- **Max 1 DM round-trip per implementation question** — then Coder decides and documents
- **Messages expire after 1 hour** — ephemeral, not permanent record
- **Messages are NOT handoffs** — don't count as gate decisions or pipeline state
- **Orchestrator always relays** — agents are stateless LLM calls
- **No message chains** — A→B→C needs a council, not DMs
- **Cross-level DMs allowed** — Coder→Architect/PO/PM, max 1 round-trip per question

## Auto-Trigger Rules

Orchestrator (opencode) should auto-trigger DMs when:

1. **Coder output diverges from Architect design** → dispatch Architect to review Coder output, DM Coder with corrections
2. **Reviewer finds architectural issue** → DM Architect for clarification before marking FAIL
3. **QA finds test gaps** → DM Coder about specific gaps
4. **Security finding needs design context** → DM Architect about intended security model

## Blackboard Integration

DM decisions are appended to the shared blackboard:

```markdown
## [Architect ↔ Coder: drift-verify-concurrency]

Decision: Semaphore(3) stays, MAX_VERIFY_DEPTH=10 added.
Rationale: 3 rounds ansible prevents API flood, depth guard prevents stack overflow.
Participants: deepseek-architect, glm-coder
```

## Resolution

- **Resolved**: participants agree → one writes `type: decision` → thread status → resolved
- **Escalated**: 3 rounds no convergence → thread status → escalated → opencode presents to user
- **Expired**: 1 hour timeout → thread status → expired → information lost (intentional)

## Cleanup

Remove `/tmp/opencode/messages/` files older than 1 hour. Resolved/expired thread metadata cleaned after 1 hour.

## Examples

### Planning Phase Challenge

```yaml
---
from: deepseek-architect
to: glm-po
timestamp: 2026-05-11T14:32:00Z
thread: sprint1-scope
type: challenge
priority: high
---
SSE/WebSocket in sprint 1? Spec says single-user, no concurrent access. Why not defer to backlog?
```

```yaml
---
from: glm-po
to: deepseek-architect
timestamp: 2026-05-11T14:33:00Z
thread: sprint1-scope
type: answer
priority: high
---
Agreed. Async apply endpoint with task polling covers the UX gap. Real-time push is nice-to-have, not needed.
```

### Coder Helping Coder

```yaml
---
from: glm-coder
to: kimi-coder
timestamp: 2026-05-11T15:00:00Z
type: question
priority: normal
---
How does the ArtifactStore handle concurrent writes? I'm adding apply endpoint and worried about race conditions.
```

```yaml
---
from: kimi-coder
to: glm-coder
timestamp: 2026-05-11T15:01:00Z
type: answer
priority: normal
---
File locks via fcntl in store.py:142. Read-acquire for read(), write-acquire for write(). Apply endpoint should be fine — only one apply per artifact at a time (status check in lifecycle.propose()).
```

### Cross-Level Guidance

```yaml
---
from: glm-coder
to: deepseek-architect
timestamp: 2026-05-11T15:10:00Z
type: question
priority: high
---
DB schema has `status` TEXT but API returns enum string. Migration adds CHECK constraint — should I also add an index on status column?
```

```yaml
---
from: deepseek-architect
to: glm-coder
timestamp: 2026-05-11T15:11:00Z
type: answer
priority: high
---
Yes on index — status filtering is hot path (list by status). Partial index WHERE status != 'applied' if you want to optimize further, but simple btree is fine for sprint 1.
```