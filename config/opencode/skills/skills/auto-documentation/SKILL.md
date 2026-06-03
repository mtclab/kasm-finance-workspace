---
name: auto-documentation
description: Automatically generate or update documentation when code changes are committed, PRs are created, features are deployed, or configs are modified. Triggers on doc, docs, documentation, README, changelog, ADR, architecture, deploy, release, merge, commit.
---

# Skill: Auto-Documentation

Automatically generate or update documentation when code, config, or infrastructure changes. Every merge, deploy, or config change MUST produce matching documentation updates.

## When to Use Me

- After committing code changes (any commit that modifies src/, scripts, or config)
- After creating or merging a PR
- After deploying to any environment
- After changing docker-compose, .env, Zabbix config, Matrix config, or n8n workflows
- After adding or modifying an API endpoint
- After creating a new skill, agent, or workflow
- When user says "doc", "docs", "documentation", "README", "changelog", "ADR", "architecture"

## Steps

### 1. Identify What Changed

```bash
# For git commits
git diff HEAD~1 --name-only

# For PRs
gh pr view <number> --json files --jq '.files[].path'

# For deployments
# Check session-state.md last-updated date vs current date
```

### 2. Determine Documentation Targets

Map changes to doc files:

| Change | Documentation Target |
|--------|---------------------|
| `src/homepilot/**/*.py` | `docs/ARCHITECTURE.md`, `docs/API.md`, inline docstrings |
| `docker-compose*.yml` | `docs/deployment.md`, `docs/ARCHITECTURE.md` |
| `.env*` | `docs/deployment.md` secrets section |
| `n8n/workflows/*.json` | `docs/n8n-workflows.md` |
| `monitoring/**/*` | `docs/monitoring.md` |
| `matrix-bridge/**/*` | `docs/matrix-bridge.md` |
| `scripts/**/*` | `docs/operations.md` |
| `tests/**/*` | Test coverage notes in `docs/ARCHITECTURE.md` |
| `src/homepilot/config.py` | `docs/configuration.md`, `docs/vault.md` |
| `src/homepilot/mcp/**` | `docs/mcp-tools.md` |
| Skill/agent files | This README or the agent's own docs |

### 3. Update the Documentation

For each target file:

1. **Read** the existing file first
2. **Update** the relevant sections — don't rewrite entire files, just change what changed
3. **Follow** existing formatting conventions in the file
4. **Add** entries to changelogs with date stamps
5. **Create** new doc files only if no existing file covers the topic

**Changelog format** (in `docs/CHANGELOG.md` or equivalent):
```markdown
## [YYYY-MM-DD] Title

### Added
- Feature X: brief description

### Changed
- Config Y: what changed and why

### Fixed
- Bug Z: brief fix description

### Security
- Secret rotation, vault change, etc.
```

**ADR format** (in `docs/adr/NNNN-title.md`):
```markdown
# NNNN: Title

- Status: Proposed/Accepted/Deprecated
- Date: YYYY-MM-DD

## Context
Why this decision was needed.

## Decision
What was decided.

## Consequences
What happens now.
```

### 4. Verify

```bash
# Check all referenced files exist
grep -r '\[.*\](.*\.md)' docs/ | while read line; do
  file=$(echo "$line" | grep -oP '\(.*?\.md\)' | tr -d '()')
  [ -f "$file" ] || echo "BROKEN LINK: $file"
done

# Check markdown lint (if mdformat available)
mdformat --check docs/*.md 2>/dev/null || echo "mdformat not available, skipping"
```

### 5. Commit

```bash
git add docs/
git commit -m "docs: update documentation for <change summary>"
```

## Per-Repo Documentation

### homepilot-v2
- `docs/ARCHITECTURE.md` — system architecture, data flow, component map
- `docs/API.md` — REST API endpoints, auth, vault
- `docs/deployment.md` — Docker compose, .env, secrets, vault
- `docs/configuration.md` — all HP_* env vars, vault secrets, auto-generation
- `docs/vault.md` — vault architecture, secret lifecycle, zero-secrets deploy
- `docs/CHANGELOG.md` — version history
- `docs/adr/` — architecture decision records

### homepilot-agent
- `docs/monitoring.md` — Zabbix setup, hosts, templates, alerting
- `docs/matrix-bridge.md` — Matrix webhook bridge architecture, deployment
- `docs/n8n-workflows.md` — workflow descriptions, env vars, credentials
- `docs/operations.md` — cron jobs, scripts, maintenance procedures
- `docs/cve-monitoring-design.md` — security update checking architecture

### proxmox-mcp
- `docs/api-audit-initial.md` — PVE API parameter issues
- `README.md` — tool listing, multi-node support, SSE transport

## Examples

### Example 1: After vault auto-passphrase feature merged
```
User: "update docs for the vault auto-passphrase change"
→ Read docs/vault.md
→ Add section on auto-generation behavior
→ Update docs/deployment.md to note zero-secrets .env
→ Add CHANGELOG entry
→ Commit
```

### Example 2: After Zabbix deployment
```
User: "document the zabbix setup"
→ Read docs/monitoring.md (create if missing)
→ Document hosts, templates, credentials location, alerting
→ Update session-state.md
→ Commit
```

### Example 3: After Matrix bridge deployment
```
User: "we just deployed matrix bridge, doc it"
→ Create docs/matrix-bridge.md
→ Document architecture, env vars, configuration
→ Update docs/ARCHITECTURE.md (or equivalent)
→ Commit
```

## Failure Modes

- **No docs directory**: Create `docs/` with README.md first
- **Existing docs are stale**: Update rather than rewrite — preserve history
- **Unsure what changed**: Run `git diff HEAD~1 --stat` to identify scope
- **Cross-repo changes**: Document in ALL affected repos, not just one
- **Auto-generated API docs**: Don't duplicate — link to source or OpenAPI spec