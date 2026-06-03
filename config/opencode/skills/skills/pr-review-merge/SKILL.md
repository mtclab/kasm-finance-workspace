---
name: pr-review-merge
description: Review and merge GitHub pull requests for HomePilot repos. Trigger on review PR, merge PR, PR review, check PR, approve PR, request changes. Covers code review, security review, test verification, merge checklist, conflict resolution.
---

# PR Review & Merge

Review, approve, and merge GitHub pull requests across HomePilot repos.

## When to Use

- User mentions reviewing, approving, or merging a PR
- Code review needed before merging
- Checking if a PR is ready (tests pass, no conflicts, approvals)
- Requesting changes on a PR
- Resolving merge conflicts

## Repos

| Repo | Path | Description |
|------|------|-------------|
| homepilot-v2 | `/home/kasm-user/repot/homepilot-v2` | Main backend + UI |
| proxmox-mcp | `/home/kasm-user/repot/proxmox-mcp` | Proxmox MCP server |
| homepilot-agent | `/home/kasm-user/repot/homepilot-agent` | Docker stack, n8n, Zabbix |

## Review Checklist

### Pre-Review
```bash
# 1. List open PRs
cd <repo> && gh pr list --state open

# 2. Check out PR branch
gh pr checkout <number>

# 3. View diff
gh pr diff <number>
```

### Review Criteria

1. **Security**: No secrets committed, vault usage correct, auth middleware unchanged
2. **Tests**: `pytest tests/ -q --ignore=tests/e2e --ignore=tests/slow` passes
3. **Lint**: `ruff check src/` clean
4. **Typecheck**: If applicable, run mypy or similar
5. **Breaking changes**: API endpoints, env vars, DB migrations documented
6. **Performance**: No N+1 queries, no sync blocking in async code
7. **Error handling**: No bare except, proper logging, user-facing errors clear
8. **Documentation**: `docs/` updated for new features

### Approval Workflow
```bash
# Approve
gh pr review <number> --approve --body "LGTM. Tests pass, lint clean, security review passed."

# Request changes
gh pr review <number> --request-changes --body "Issues: 1) Missing test for X, 2) Secret in .env.example"

# Comment
gh pr comment <number> --body "Question: Should this be configurable?"
```

### Merge Workflow
```bash
# 1. Verify CI passes
gh pr checks <number>

# 2. Verify no conflicts
gh pr view <number> --json mergeable --jq .mergeable

# 3. Squash merge (preferred for feature branches)
gh pr merge <number> --squash --delete-branch

# 4. Verify merge
gh pr view <number> --json state --jq .state
```

### Conflict Resolution
```bash
# 1. Update branch from base
gh pr checkout <number>
git fetch origin main
git merge origin/main

# 2. Resolve conflicts manually
# Edit conflicted files...

# 3. Commit and push
git add .
git commit -m "merge: resolve conflicts with main"
git push

# 4. Verify CI passes
gh pr checks <number>
```

## Examples

### Review HomePilot v2 PR
```bash
cd /home/kasm-user/repot/homepilot-v2
gh pr list --state open
gh pr checkout 179
.venv/bin/ruff check src/
.venv/bin/python -m pytest tests/ -q --ignore=tests/e2e
gh pr review 179 --approve
gh pr merge 179 --squash --delete-branch
```

### Review Proxmox MCP PR
```bash
cd /home/kasm-user/repot/proxmox-mcp
gh pr list --state open
gh pr checkout <number>
pytest tests/ -q
ruff check src/
gh pr review <number> --approve
gh pr merge <number> --squash --delete-branch
```

## Failure Modes

- **CI failing**: Do not merge. Fix issues or request changes.
- **Merge conflict**: Resolve locally, push, then merge.
- **Missing tests**: Request changes — require test coverage for new features.
- **Secret in diff**: Block merge immediately, rotate secret, request changes.
- **Breaking API change**: Ensure migration path documented before merge.