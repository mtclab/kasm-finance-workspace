Caveman ALWAYS ON. All agent comms terse. Technical substance exact. Fluff dies.
- Agents: caveman comms. Code: normal. Commits: normal. PRs: proper English.
- Drop: articles, filler, pleasantries, hedging.
- Fragments OK. Pattern: [thing] [action] [reason]. [next step].
- Off: "stop caveman" / "normal mode".
ACTIVE EVERY RESPONSE. No revert. No drift.

---

# Agent System — see split files for details

- **roles.md** — Models, variants, dispatch rules, council compositions
- **workflow.md** — 5-phase pipeline, planning/ranking/implementation details
- **matrix.md** — Matrix MCP tools for real-time agent communication
- **handoffs.md** — File structure, handoff contracts, naming conventions
- **prompts.md** — Per-role agent prompts

## Key Principles

1. Agents communicate via **Matrix MCP tools** (real-time) + **handoff documents** (permanent)
2. Max 10 parallel agents (cloud capacity). Max 5 gate cycles. One issue = one branch + commit + PR.
3. Lint/typecheck runs automatically after every Coder dispatch.
4. Commit only when user asks.
5. Never commit secrets to git — store in `/home/kasm-user/.config/opencode/secrets/` only.
6. 12 agent roles: Architect, PO, PM, Coder, Reviewer, QA, Security, UX, DevOps, InfraOps, DataEngineer, Integrator

## Matrix MCP Tools (agent communication)

| Tool | Purpose |
|------|---------|
| `matrix_read` | Read messages from room (role, limit, since, filter_type) |
| `matrix_post` | Post message as agent role (role, msg_type, content) |
| `matrix_read_positions` | Read position messages (role, since) |
| `matrix_read_converged` | Read converged decisions (role) |
| `matrix_who_is_here` | List agent members (role) |
| `matrix_post_reaction` | React to message (role, event_id, emoji) |

Message types: position, challenge, agreement, converged, decision, heads-up, question, answer, escalation

## Handoff Contracts (permanent record)

All gate decisions use handoff documents in `~/.config/opencode/handoffs/` (symlinked `/tmp/opencode/handoffs/`).
See **handoffs.md** for full contract details and naming conventions.

## Quick Reference

- Matrix server: `https://matrix.mtcchat.com`
- Room: `!9PnzYFd37ezepO_4f8lzeSjhzSXuP-JO8ZoJjI5znHU`
- Bots: `@hp-{architect,po,pm,coder,reviewer,qa,security,ux,devops,infraops,dataengineer,integrator}:mtcchat.com`
- Tokens: `/home/kasm-user/.config/opencode/secrets/matrix_tokens.json`
- Ollama cloud: `http://open-webui-ollama:11434/v1`
- GitHub repos: `mtclab/homepilot-v2`, `mtclab/proxmox-mcp`, `mtclab/homepilot-agent`
- Dev server: `10.96.16.18`
- Proxmox: `10.96.16.19` — NEVER commit credentials