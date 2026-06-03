# Matrix MCP Tools — Agent Communication Layer

Agents communicate via **Matrix MCP tools** for real-time deliberation and **handoff documents** for gate decisions.

## Server

Custom Matrix MCP server: `homepilot.mcp.matrix_server`
Configured in `opencode.json` as local stdio MCP server.
Matrix server: `https://matrix.mtcchat.com`
Room: `!9PnzYFd37ezepO_4f8lzeSjhzSXuP-JO8ZoJjI5znHU` ("HomePilot Agents")
12 bot accounts: `@hp-{architect,po,pm,coder,reviewer,qa,security,ux,devops,infraops,dataengineer,integrator}:mtcchat.com`
Tokens: `/home/kasm-user/.config/opencode/secrets/matrix_tokens.json`

## Available Tools

| Tool | Purpose | Params |
|------|---------|--------|
| `matrix_create_thread` | Create a new thread, return its root event ID. Orchestrator-only. | role, topic |
| `matrix_read` | Read messages from room (filtered to a thread when thread_root set). | role, limit, since, filter_type, **thread_root** |
| `matrix_post` | Post message as agent role (within a thread when thread_root set). | role, msg_type, content, **thread_root** |
| `matrix_read_positions` | Read position-type messages. | role, since, **thread_root** |
| `matrix_read_converged` | Read converged decisions. | role, **thread_root** |
| `matrix_who_is_here` | List agent members. | role |
| `matrix_post_reaction` | React to a message (use instead of `agreement` msg_type). | role, event_id, emoji |

Always pass `thread_root` to read/post when the orchestrator has provided one. See **Threading** below.

## Message Types

| Type | Emoji | Purpose |
|------|-------|---------|
| `position` | 📋 | Initial position / proposal |
| `challenge` | ⚔️ | Push back on an assumption |
| `agreement` | ✅ | Agree with a position |
| `converged` | 🎯 | Converged decision point |
| `decision` | ⚡ | Final decision |
| `heads-up` | 📢 | FYI without expecting response |
| `question` | ❓ | Ask something |
| `answer` | 💡 | Respond to a question |
| `escalation` | 🚨 | Escalate to user |

## How Agents Use It

Agents call MCP tools directly during dispatch. No scripts needed.

**Planning phase**: Each agent writes full position to handoff file, then posts a 1-line summary pointer to Matrix.
```python
# Write full position first
# path = /tmp/opencode/issues/{issue_n}/council/R1-architect.md

# Post ONE-LINE summary + pointer (Matrix is for observability, not the full content)
matrix_post(role="architect", msg_type="position",
            content="SQLite over PostgreSQL — see /tmp/opencode/issues/{issue_n}/council/R1-architect.md",
            thread_root=thread_root)

# Read others' summaries, then read their linked handoff files for details
matrix_read(role="architect", filter_type="position", thread_root=thread_root)

# Challenge: post 1-line challenge pointing to your response file
matrix_post(role="architect", msg_type="challenge",
            content="Semaphore(3) too conservative — see R2-architect-response.md",
            thread_root=thread_root)

# Converge
matrix_post(role="architect", msg_type="converged",
            content="SQLite for HomePilot v2 — single user, embedded",
            thread_root=thread_root)
```

**Implementation phase**: Coder asks Architect for guidance (always include thread_root).
```python
# Coder posts a question
matrix_post(role="coder", msg_type="question",
            content="DB schema doesn't match API contract — which takes priority?",
            thread_root=thread_root)

# Architect responds
matrix_read(role="architect", filter_type="question", thread_root=thread_root)
matrix_post(role="architect", msg_type="answer",
            content="API contract wins. Add migration in next PR.",
            thread_root=thread_root)
```

**Gate decisions**: Still use handoff documents (permanent record). Matrix is for real-time deliberation only.

## Threading

Every agent receives a `thread_root` event ID in its dispatch prompt and must pass it on every `matrix_post` and `matrix_read` call. This isolates concurrent work items — parallel Coders working different issues never see each other's traffic.

| Phase | Thread scope |
|-------|-------------|
| Planning council (pre-issue) | One thread per council session |
| Issue ranking | One thread per ranking session |
| Per-issue implementation | One thread per issue |
| Per-issue gate cycle | One thread per cycle (nested under issue thread) |
| Pair-coding pair | Pair shares the issue's thread; navigator reads/writes same thread |

Orchestrator calls `matrix_create_thread(role, topic)` at the start of each phase and records the returned event ID in `/tmp/opencode/issues/{n}/thread_roots.json`. The event ID is then injected as `{thread_root}` into every agent dispatch prompt for that phase.

## Constraints

- **Max 10 parallel agents** (cloud capacity) — all phases can run wider
- **Max 3 rounds** per deliberation thread — converge or escalate
- **Max 1 question round-trip** per implementation question — then decide and document
- **Matrix is ephemeral** — handoff documents are permanent record
- **Orchestrator relays** — agents are stateless, opencode orchestrates reads/writes
- **No chains** — A→B→C needs a council, not Matrix messages
- **Watch in Element** — user `@kolli:mtcchat.com` can observe all messages live