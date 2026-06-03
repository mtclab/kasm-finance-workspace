# Skill-Embedded MCP Server Configurations

## Overview

OpenCode skills can declare MCP server dependencies directly in their `SKILL.md` frontmatter. When a skill is loaded, opencode spins up the declared MCP servers and makes their tools available to the agent. Servers are torn down after skill execution completes.

## Schema

Add an optional `mcp` section to SKILL.md YAML frontmatter:

```yaml
---
name: my-skill
description: What this skill does
mcp:
  servers:
    - name: server-name          # Required. Unique identifier for this server
      type: local                # Required. "local" (stdio) or "remote" (SSE/streamable-http)
      command: [...]             # Required for local. Command array to start the server
      url: https://...           # Required for remote. Server URL
      env:                       # Optional. Environment variables
        KEY: value
      headers:                   # Optional. HTTP headers (remote only)
        Authorization: Bearer ...
      timeout: 15000             # Optional. Milliseconds per tool call (default: 10000)
      args: [...]                # Optional. Additional CLI args (local only)
---
```

## Server Types

### Local (stdio)

Local servers are started as child processes communicating over stdio. The `command` field is a string array — the first element is the executable, remaining elements are arguments.

```yaml
mcp:
  servers:
    - name: deploy-ssh
      type: local
      command: ["/usr/bin/python3", "-m", "mypackage.mcp.server"]
      env:
        TARGET_HOST: "10.96.16.18"
      timeout: 15000
```

### Remote (SSE / Streamable HTTP)

Remote servers connect over HTTP. The `url` field is the server endpoint.

```yaml
mcp:
  servers:
    - name: analytics-api
      type: remote
      url: "https://analytics.example.com/mcp"
      headers:
        Authorization: "Bearer ${ANALYTICS_TOKEN}"
      timeout: 30000
```

## Environment Variables

- Values in `env` are passed as-is to the server process
- Use `${VAR}` syntax to reference the agent's runtime environment (opencode resolves these before server start)
- Secrets must come from `/home/kasm-user/.config/opencode/secrets/` — never hardcode credentials

## Lifecycle

1. **Skill loads** → opencode reads `mcp.servers` from frontmatter
2. **Servers start** → each server is launched in dependency order (future: support `depends_on`)
3. **Tools available** → agent can call any tool exposed by the MCP servers
4. **Skill completes** → all skill-scoped servers are torn down

### Error Handling

- If a server fails to start, the skill load fails with a descriptive error
- If a tool call times out, the agent receives a timeout error and can retry or abort
- Server crashes mid-skill are logged; the agent is notified via tool error

## Examples

### Deploy Skill

```yaml
---
name: deploy
description: Deploy HomePilot to dev server or rollback
mcp:
  servers:
    - name: deploy-ssh
      type: local
      command: ["/home/kasm-user/repot/agent-venv/bin/python3", "-m", "homepilot.mcp.deploy_server"]
      env:
        DEPLOY_SERVER: "10.96.16.18"
        DEPLOY_USER: "bilvi-homepilot"
      timeout: 15000
---
```

### Remote API Skill

```yaml
---
name: infra-monitor
description: Monitor infrastructure via MCP gateway
mcp:
  servers:
    - name: prometheus-mcp
      type: remote
      url: "https://monitoring.internal:9090/mcp"
      headers:
        Authorization: "Bearer ${PROM_TOKEN}"
      timeout: 30000
---
```

### Multi-Server Skill

```yaml
---
name: full-test
description: Run integration tests with multiple MCP backends
mcp:
  servers:
    - name: test-db
      type: local
      command: ["python3", "-m", "testkit.db_server"]
      env:
        DB_URL: "postgresql://localhost:5432/test"
    - name: test-http
      type: local
      command: ["python3", "-m", "testkit.http_mock"]
---
```

## Compatibility

- Skills without an `mcp` section work exactly as before — no changes required
- Global MCP servers (Context7, Matrix, etc.) remain available alongside skill-scoped ones
- Skill-scoped servers do not persist across skill invocations
- If two skills declare the same server name, they are treated as separate instances (scoped to each skill execution)

## Implementation Notes

For the opencode runtime:

1. Parse `mcp.servers` from SKILL.md frontmatter (YAML)
2. On skill load, initialize each declared server:
   - `local`: spawn child process with stdio transport, inject `env`
   - `remote`: connect via SSE/streamable-http with `headers`
3. Register all tools from each server into the agent's tool namespace, prefixed with the server name (e.g., `deploy-ssh.deploy_pull`)
4. On skill unload/completion, send shutdown signal and wait for graceful exit, then force-kill after 5s
5. Report server start failures immediately; do not silently proceed