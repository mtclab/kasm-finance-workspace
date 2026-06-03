# MCP Tool Reference (include in agent dispatch prompts)

Agents have access to Matrix MCP (7 tools incl. threading) and Context7 MCP
(2 tools). Include the relevant sections below when dispatching agents via the
task tool.

---

## Matrix MCP Tools (agent-to-agent real-time communication)

You have Matrix MCP tools for communicating with other agents in real time.
The Matrix room has 7 bots: architect, po, pm, coder, reviewer, qa, security.

### Tool: matrix_create_thread
Create a new thread and return its root event ID. Used by orchestrator at phase start.
- `role` (required): your agent role
- `topic` (required): short description (e.g. "issue-42-implementation")
- Returns: `{"event_id": "..."}` — store in `thread_roots.json`

### Tool: matrix_read
Read messages from the room (filtered to a thread when thread_root is set).
- `role` (required): your agent role — "architect" | "po" | "pm" | "coder" | "reviewer" | "qa" | "security"
- `limit` (optional): max messages to return, default 50
- `since` (optional): event ID — only return messages after this event
- `filter_type` (optional): "position" | "challenge" | "agreement" | "converged" | "decision" | "heads-up" | "question" | "answer" | "escalation"
- `thread_root` (optional but CRITICAL): event ID — only return messages in this thread. **MUST always be passed when a thread exists. Messages without thread_root go to the room and are invisible to other agents in the thread.**

### Tool: matrix_post
Post a message as your agent role. **Always include thread_root when one exists.**
- `role` (required): your agent role
- `msg_type` (required): "position" | "challenge" | "agreement" | "converged" | "decision" | "heads-up" | "question" | "answer" | "escalation"
- `content` (required): message text — keep to 1 line; link to handoff file for details
- `thread_root` (optional but CRITICAL): event ID of thread root — **MUST always be passed. Messages without thread_root go to the room and are invisible to agents in the thread.**
- Returns: `{"event_id": "..."}` of new message

### Tool: matrix_read_positions
Read only position-type messages. Params: role, since (optional), thread_root (optional)

### Tool: matrix_read_converged
Read converged decisions. Params: role, thread_root (optional)

### Tool: matrix_who_is_here
List which bots are in the room. Params: role

### Tool: matrix_post_reaction
React to a specific message with emoji. Use instead of posting an `agreement` message.
- `role` (required): your agent role
- `event_id` (required): event ID to react to
- `emoji` (required): emoji string (e.g., "+1", "-1", "eyes", "rocket")

### When to use Matrix vs handoff files

| Scenario | Matrix message | Handoff file |
|----------|---------------|--------------|
| Proposing a position during deliberation | 1-line pointer (summary + file path) | Full content (canonical) |
| Challenging another agent's assumption | 1-line pointer to response file | Full response (canonical) |
| Asking another agent a question | YES | No |
| Answering another agent's question | YES | No |
| Recording final gate verdict (PASS/FAIL) | No | YES (mandatory, canonical) |
| Recording design decisions | No | YES (mandatory, canonical) |
| FYI / progress update | YES (heads-up) | No |
| Escalating to user | YES (escalation) | YES (full context, canonical) |

Rule: full content lives in handoff files (the canonical source). Matrix posts
are short pointers so the room stays scannable and tokens stay cheap.

### Typical flows

**Council deliberation (planning agents) — always pass thread_root:**
1. Write full position to handoff file, then post 1-line summary pointer: `matrix_post(role="architect", msg_type="position", content="1-line summary — see /tmp/.../R1-architect.md", thread_root=thread_root)`
2. Read others' pointers, then read their linked handoff files: `matrix_read(role="architect", filter_type="position", thread_root=thread_root)`
3. Write response to file, post 1-line: `matrix_post(role="architect", msg_type="challenge", content="summary — see R2-architect-response.md", thread_root=thread_root)`
4. Post converged: `matrix_post(role="architect", msg_type="converged", content="agreed: SQLite — see council.md", thread_root=thread_root)`

**Implementation question (coder asking architect) — always pass thread_root:**
1. `matrix_post(role="coder", msg_type="question", content="DB schema doesn't match API contract — which wins?", thread_root=thread_root)`
2. Wait, then: `matrix_read(role="coder", filter_type="answer", thread_root=thread_root)`
3. Max 1 round-trip per question — then decide and document.

### Constraints
- Max 3 rounds per deliberation thread — converge or escalate
- Max 1 question round-trip per implementation question
- Matrix is ephemeral — handoff documents are permanent record
- No chains (A→B→C needs a council, not Matrix messages)
- Always write both Matrix post AND handoff file for positions and decisions

---

## Context7 MCP Tools (documentation lookup)

You have Context7 MCP tools to look up library documentation and code examples
for any programming library or framework. Use these when you need to understand
how to use a library, API, or framework correctly.

### Tool: resolve-library-id
Resolve a library name to a Context7-compatible library ID.
- `libraryName` (required): official library name (e.g., "Svelte", "FastAPI", "SQLAlchemy")
- `query` (required): what you need help with (e.g., "how to create a FastAPI dependency")

**Always call this FIRST before query-docs.** Returns: library ID, description,
code snippet count, benchmark score.

### Tool: query-docs
Query documentation and code examples for a library.
- `libraryId` (required): Context7 library ID from resolve-library-id (e.g., "/tiangolo/fastapi")
- `query` (required): specific question (e.g., "how to set up async lifespan events in FastAPI")

### When to use Context7

| Scenario | Use Context7 |
|----------|-------------|
| Unsure about a library API signature | YES |
| Need code examples for a pattern | YES |
| Checking if a library supports a feature | YES |
| Understanding Pydantic models, FastAPI deps, Svelte stores, etc. | YES |
| Questions about our own codebase | NO — use file read/grep tools instead |

### Typical flow
1. `resolve-library-id(libraryName="FastAPI", query="how to set up lifespan events")`
2. From results, pick the best match (highest benchmark score + relevance)
3. `query-docs(libraryId="/tiangolo/fastapi", query="how to set up async lifespan events")`
4. Use the returned docs/examples to write correct code

### Constraints
- Max 3 calls per question (1 resolve + 2 queries)
- Always resolve first, then query — never guess a library ID
- For version-specific queries, include the version in libraryName