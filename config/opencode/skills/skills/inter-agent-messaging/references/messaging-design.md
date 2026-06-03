# Inter-Agent Messaging Protocol

## Problem

Current orchestra: agents communicate via structured handoff documents. The orchestrator routes file paths, not contents. This is:
- **Slow**: one round per handoff cycle (write file → dispatch next agent → read → respond)
- **Lossy**: orchestrator compresses context between stages
- **Rigid**: no way for agents to ask each other clarifying questions mid-handoff
- **Isolated**: agents can't challenge each other's assumptions outside council deliberation

Council deliberation proves the value of multi-round agent discussion. But councils are heavy — 3 agents × 2 rounds = 6 dispatches. For quick questions, that's overkill.

## Design

### Two Communication Modes

| Mode | When | Format | Latency | Persistence |
|------|------|--------|---------|-------------|
| **Direct Message** | Quick question, clarification, challenge | Short text | Low | Ephemeral (1 hour) |
| **Handoff Document** | Gate decisions, stage transitions, multi-cycle review | YAML + Markdown | High | Permanent |

Direct messages are **ephemeral chat** between agents. Handoffs are **permanent record** for the pipeline.

### Message Format

```
/tmp/opencode/messages/
├── {from}-{to}-{seq}.md          # Direct message (ephemeral)
├── {from}-{to}-{seq}.md          # Reply
└── threads/
    ├── {thread-id}.json          # Thread metadata
    └── {thread-id}/              # Thread messages
        ├── 001-{from}-{to}.md
        ├── 002-{to}-{from}.md
        └── 003-{from}-{to}.md
```

### Message Schema

```yaml
---
from: deepseek-architect
to: glm-coder
timestamp: 2026-05-11T14:32:00Z
thread: drift-verify-concurrency    # optional — groups messages into a thread
type: question | answer | challenge | clarification | heads-up | decision
priority: low | normal | high
---
```

Message body: freeform markdown. Short and direct. Caveman comms apply.

### Thread Schema

```json
{
  "thread_id": "drift-verify-concurrency",
  "participants": ["deepseek-architect", "glm-coder"],
  "started_at": "2026-05-11T14:32:00Z",
  "status": "open | resolved | escalated",
  "resolution": null,
  "message_count": 3
}
```

### Message Types

| Type | Purpose | Example |
|------|---------|---------|
| `question` | Ask another agent something | "Does verify_artifact handle executor=None?" |
| `answer` | Respond to a question | "Yes — returns VerifyResult(drifted=False, reason='no_executor')" |
| `challenge` | Push back on an assumption | "Your Semaphore(3) is too conservative for 20-host fleets" |
| `clarification` | Ask for more detail | "What error codes does git subprocess return on lock?" |
| `heads-up` | FYI without expecting response | "I changed verify_artifact signature — added _depth param" |
| `decision` | State a resolved decision | "Semaphore(3) stays. Added _MAX_VERIFY_DEPTH=10 instead." |

### Flow

```
1. Agent A is dispatched (task tool)
2. During execution, Agent A wants to ask Agent B something
3. Agent A writes a message:
   /tmp/opencode/messages/deepseek-architect->glm-coder-001.md
   (or to a thread if one exists)
4. Agent A returns — its task output tells opencode "waiting on reply from glm-coder"
5. opencode dispatches Agent B with:
   - The message as context
   - Instruction to respond
6. Agent B writes reply:
   /tmp/opencode/messages/glm-coder->deepseek-architect-001.md
7. opencode re-dispatches Agent A (resume via task_id) with the reply
8. Agent A continues with the new information
```

### Constraints

1. **Max 3 messages per thread** — if agents can't converge in 3 exchanges, escalate to user or council
2. **Max 1 message round-trip per pipeline stage** — don't let Chatting delay gate decisions
3. **Messages expire after 1 hour** — ephemeral, not permanent record
4. **Messages are NOT handoffs** — they don't count as gate decisions or pipeline state
5. **Orchestrator always relays** — agents never talk directly (they're stateless LLM calls)
6. **No message chains** — if A→B→C is needed, that's a council, not messaging

### When to Use Direct Messages vs Alternatives

| Situation | Use |
|-----------|-----|
| Architect asks Coder a quick question about implementation | **Direct message** |
| Coder needs clarification on a design decision | **Direct message** |
| Reviewer challenges Architect's approach | **Direct message** |
| 2-3 agents need to debate before implementation | **Council deliberation** |
| Gate agent needs to report PASS/FAIL | **Handoff document** |
| Coder reports files changed | **Handoff document** |
| Agent notices something irrelevant to current task | **Heads-up message** |
| Disagreement after 3 message rounds | **Escalate to user** |

### Integration with Existing Pipeline

```
Normal flow:
  Architect → Coder → Reviewer → QA → Security

With messaging:
  Architect → Coder ←→ (messages with Architect) → Reviewer → QA ←→ (messages with Coder about test gaps) → Security
  
  The pipeline still flows sequentially through gates.
  Messages happen WITHIN a stage or between adjacent stages.
  They don't skip stages or bypass gates.
```

### Auto-Trigger Rules

The orchestrator (opencode) should auto-trigger messages when:

1. **Coder output diverges from Architect design** → dispatch Architect to review Coder output, message Coder with corrections
2. **Reviewer finds architectural issue** → message Architect for clarification before marking FAIL
3. **QA finds test gaps** → message Coder about specific gaps
4. **Security finding needs design context** → message Architect about intended security model

### Thread Resolution

- **Resolved**: participants agree → one writes `type: decision` message → thread status → resolved
- **Escalated**: 3 rounds without convergence → thread status → escalated → opencode presents to user
- **Expired**: 1 hour timeout → thread status → expired → information lost (that's intentional — it's ephemeral)

### Blackboard Integration

Messages are NOT appended to the blackboard (it's append-only permanent record). But if a message leads to a decision, that decision IS appended:

```markdown
## [Architect ↔ Coder: drift-verify-concurrency]

Decision: Semaphore(3) stays for ansible, _MAX_VERIFY_DEPTH=10 added for composites.
Rationale: 3 rounds ansible prevents API flood, depth guard prevents stack overflow.
Participants: deepseek-architect, glm-coder
```

### Implementation in AGENTS.md

The orchestrator (opencode) needs these additions:

1. **Message dispatch**: after an agent returns and requests a reply, dispatch the target agent
2. **Message resume**: re-dispatch the requesting agent with the reply (via task_id resume)
3. **Thread tracking**: maintain thread state in `/tmp/opencode/messages/threads/`
4. **Expiration**: cleanup messages older than 1 hour
5. **Escalation**: present unresolved threads to user after 3 rounds

### Example Session

```
1. opencode dispatches Architect → design handoff
2. Architect writes handoff, notices Coder will need to know about git concurrency
3. Architect writes heads-up message:
   /tmp/opencode/messages/deepseek-architect->glm-coder-001.md
   ---
   from: deepseek-architect
   to: glm-coder
   type: heads-up
   ---
   git subprocess calls have no timeout. Add timeout=30 before implementing apply UI.

4. opencode dispatches Coder (with message as context)
5. Coder reads message, implements with timeouts
6. Coder writes question back:
   /tmp/opencode/messages/glm-coder->deepseek-architect-001.md
   ---
   from: glm-coder
   to: deepseek-architect
   type: question
   thread: git-timeouts
   ---
   Should I add retry logic too, or just timeout + error classification?

7. opencode dispatches Architect (brief, resume context)
8. Architect replies:
   /tmp/opencode/messages/deepseek-architect->glm-coder-002.md
   ---
   from: deepseek-architect
   to: glm-coder
   type: answer
   thread: git-timeouts
   ---
   Timeout + classification only. Retry adds complexity for marginal benefit — user can retry manually.

9. opencode re-dispatches Coder (resume via task_id with answer)
10. Coder continues, appends decision to blackboard
```

### Why Not Just Use the Task Tool?

The task tool dispatches full sub-agents. Each dispatch:
- Fresh LLM context (no conversation history)
- Full task description needed
- Output returned to orchestrator, not to requesting agent

Direct messages are **lighter**: the requesting agent's context is preserved (via task_id resume), the message is short (not a full task prompt), and the reply goes directly into the requesting agent's next turn — not through the orchestrator's interpretation.

The key difference: **task tool = orchestration, direct messages = conversation.**