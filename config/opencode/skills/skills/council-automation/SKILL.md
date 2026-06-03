# Skill: Planning Council Automation

Automate the full planning council pipeline: dispatch agents, collect positions, converge, create GitHub issues.

## When to Use

- User says "plan next sprint", "council", "what should we work on next", "prioritize", "rank issues"
- User asks to automate issue creation from council decisions
- User says "dispatch council" or "start planning"

## Prerequisites

- Matrix tokens at `/home/kasm-user/.config/opencode/secrets/matrix_tokens.json`
- Matrix room configured in `/home/kasm-user/.config/opencode/secrets/matrix_room.json`
- Agent config files in `~/.config/opencode/agents/` (roles.md, workflow.md, prompts.md)
- Blackboard at `/tmp/opencode/issues/pre-issue/blackboard.md`

## Steps

### 1. Prepare Blackboard

Write `/tmp/opencode/issues/pre-issue/blackboard.md` with:
- Current state of each repo (deployed version, open issues, test results)
- Key source files to read
- Questions for the council
- Relevant context (benchmarks, constraints, capacity)

Include `homepilot-agent` repo context when relevant:
- Stack: llama.cpp (Qwen3-14B), n8n workflows, SearXNG, Radicale
- Agent tiers: HomePilot (IaC), opencode orchestra (dev agents), n8n (personal agent + notifications)
- MCP tools: query_inventory, get_environment_doc, search_kb, record_fact, propose_artifact
- GPU layout: 3× RTX 4000 Ada SFF, GPU 0 for LLM, GPU 1-2 idle

### 2. Create Matrix Thread

```
matrix_create_thread(role='architect', topic='planning-council-YYYY-MM-DD')
```

Record the returned `event_id` — this is `{thread_root}` for all subsequent posts.

### 3. Dispatch Council Agents (Round 1)

Choose council size based on request importance:
- **Full (6-10)**: Major features, architecture changes
- **Standard (4-5)**: Regular features
- **Bug fix (3)**: Targeted fixes

Dispatch via `task()` in parallel. Each agent MUST:
1. Read the blackboard
2. Read relevant source files
3. Write position to `/tmp/opencode/issues/pre-issue/council/R1-{model}-{role}.md`
4. Post 1-line summary to Matrix with `thread_root`

**CRITICAL**: Pass `thread_root` parameter to agents so they post in the thread, not the main room.

Model → Role mapping (from `~/.config/opencode/agents/roles.md`):
- kimi-k2.6 → Architect
- kimi-k2.6 → PO/PM/Reviewer
- glm-5.1 → DataArchitect/SecurityAuditor/WebDev
- minimax-m2.7 → DevOpsEngineer
- qwen3-coder-next → ClientSquad/ToolingSquad
- deepseek-v4-flash → Navigator/quick triage
- qwen3.5 → UXResearcher/council diversity
- nemotron-3-super → council diversity/governance
- kimi-k2.5 → PO backup/reasoning
- minimax-m2.5 → DevOps backup
- deepseek-v3.2 → Coder variant/Reviewer backup
- glm-5 → legacy review/council diversity

### 4. Read Positions from Thread

```
matrix_read(role='architect', thread_root={thread_root}, limit=20)
```

Also read position files from `/tmp/opencode/issues/pre-issue/council/`.

### 5. Round 2 (Optional — Challenge/Converge)

If council is large or positions diverge:
- Dispatch agents again to read others' positions and write responses
- Files: `R2-{model}-{role}-response.md`
- Matrix posts: `challenge` type

### 6. Synthesize Council Output

Write `/tmp/opencode/issues/pre-issue/council.md` with:
- Consensus items (all agree)
- Divergence items (some disagree)
- Priority ranking with estimates
- **Security findings** (flag immediately)
- GitHub issues to create

### 7. Post Converged Decision

```
matrix_post(role='architect', msg_type='converged', content='...', thread_root={thread_root})
```

### 8. Create GitHub Issues

For each consensus item:
```bash
gh issue create --repo mtclab/homepilot-v2 \
  --title "type: short description" \
  --label "bug|enhancement|security,component" \
  --body '## [Feature|Bug|Security]
  [Description from council]
  ## Acceptance Criteria
  [From council positions]
  ## Effort
  [From council estimates]'
```

Also create issues in `mtclab/homepilot-agent` when relevant (GPU, n8n, voice).

### 9. Close Stale Issues

```bash
gh issue close {number} --repo mtclab/homepilot-v2 --comment "Fixed in vX.Y.Z (deployed). [explanation]"
```

### 10. Update Blackboard

Append council decisions to `/tmp/opencode/issues/pre-issue/blackboard.md`.

## Automation Opportunities

### What Can Be Automated

| Step | Manual? | Automation |
|------|---------|------------|
| Prepare blackboard | Semi | Script reads git log, open issues, deployed version, writes template |
| Create Matrix thread | Auto | `matrix_create_thread` MCP tool |
| Dispatch agents | Auto | Loop through model→role mapping, create task() calls |
| Read positions | Auto | `matrix_read` MCP tool + glob council/*.md files |
| Synthesize | Semi | Manual review of positions, write council.md |
| Create GH issues | Auto | Parse council.md, `gh issue create` for each item |
| Close stale issues | Auto | Compare open issues with deployed version changelog |
| Post converged | Auto | `matrix_post` MCP tool |

### Script: Auto-Blackboard Generator

```bash
#!/bin/bash
# auto-blackboard.sh — generates blackboard.md from repo state
REPO=/home/kasm-user/repot/homepilot-v2
AGENT_REPO=/home/kasm-user/repot/homepilot-agent

echo "# Blackboard: $(date +%Y-%m-%d)" > /tmp/opencode/issues/pre-issue/blackboard.md
echo "" >> /tmp/opencode/issues/pre-issue/blackboard.md
echo "## Current State" >> /tmp/opencode/issues/pre-issue/blackboard.md
echo "" >> /tmp/opencode/issues/pre-issue/blackboard.md
echo "### homepilot-v2" >> /tmp/opencode/issues/pre-issue/blackboard.md
echo "- Version: $(grep 'version =' $REPO/pyproject.toml | head -1 | cut -d'"' -f2)" >> /tmp/opencode/issues/pre-issue/blackboard.md
echo "- Deployed: $(curl -s http://10.96.16.18:8000/health | jq -r '.version // "unknown"')" >> /tmp/opencode/issues/pre-issue/blackboard.md
echo "- Open issues: $(gh issue list --repo mtclab/homepilot-v2 --state open | wc -l)" >> /tmp/opencode/issues/pre-issue/blackboard.md
echo "- Latest commit: $(cd $REPO && git log --oneline -1)" >> /tmp/opencode/issues/pre-issue/blackboard.md
echo "- Tests: $(cd $REPO && source .venv/bin/activate && python -m pytest tests/ -x -q --co 2>/dev/null | tail -1 || echo 'N/A')" >> /tmp/opencode/issues/pre-issue/blackboard.md
echo "" >> /tmp/opencode/issues/pre-issue/blackboard.md
echo "### homepilot-agent" >> /tmp/opencode/issues/pre-issue/blackboard.md
echo "- Latest commit: $(cd $AGENT_REPO && git log --oneline -1)" >> /tmp/opencode/issues/pre-issue/blackboard.md
echo "- Stack: llama.cpp (Qwen3-14B Q8_0), n8n, SearXNG, Radicale" >> /tmp/opencode/issues/pre-issue/blackboard.md
echo "- GPUs: 3× RTX 4000 Ada SFF, GPU 0 active" >> /tmp/opencode/issues/pre-issue/blackboard.md
echo "" >> /tmp/opencode/issues/pre-issue/blackboard.md

# List open issues
echo "## Open Issues" >> /tmp/opencode/issues/pre-issue/blackboard.md
gh issue list --repo mtclab/homepilot-v2 --state open >> /tmp/opencode/issues/pre-issue/blackboard.md
echo "" >> /tmp/opencode/issues/pre-issue/blackboard.md

# Questions for council
echo "## Questions for Council" >> /tmp/opencode/issues/pre-issue/blackboard.md
echo "1. What's the highest-value next feature?" >> /tmp/opencode/issues/pre-issue/blackboard.md
echo "2. Should homepilot-agent get deeper integration?" >> /tmp/opencode/issues/pre-issue/blackboard.md
echo "3. Any remaining bugs before new features?" >> /tmp/opencode/issues/pre-issue/blackboard.md
```

### Script: Auto-Issue Creator from Council.md

```bash
#!/bin/bash
# auto-create-issues.sh — parses council.md and creates GitHub issues
# Usage: auto-create-issues.sh /tmp/opencode/issues/pre-issue/council.md

COUNCIL_FILE=${1:-/tmp/opencode/issues/pre-issue/council.md}
REPO="mtclab/homepilot-v2"

# Parse council.md for issue items (lines starting with | and containing P0/P1/P2)
grep -E '^\|.*P[0-3]' "$COUNCIL_FILE" | while read -r line; do
    # Extract priority, title, effort from table row
    PRIORITY=$(echo "$line" | awk -F'|' '{gsub(/ /,"",$2); print $2}')
    TITLE=$(echo "$line" | awk -F'|' '{print $3}' | xargs)
    EFFORT=$(echo "$line" | awk -F'|' '{print $4}' | xargs)
    
    LABEL="enhancement"
    if echo "$TITLE" | grep -qi "security\|auth\|KB.*auth"; then
        LABEL="bug,security"
    elif echo "$TITLE" | grep -qi "CI\|integration test\|rollback"; then
        LABEL="ci"
    elif echo "$TITLE" | grep -qi "KB\|reindex\|ingestion"; then
        LABEL="enhancement,kb"
    elif echo "$TITLE" | grep -qi "MCP\|webhook\|notification"; then
        LABEL="enhancement,mcp"
    fi
    
    echo "Creating: [$PRIORITY] $TITLE ($EFFORT) [$LABEL]"
    # Uncomment to actually create:
    # gh issue create --repo "$REPO" --title "$TITLE" --label "$LABEL" --body "Priority: $PRIORITY. Effort: $EFFORT. See council.md for details."
done
```

### Future: Fully Automated Council via opencode Skills

This skill can be extended to:
1. Auto-generate blackboard from git state + open issues + deployed version
2. Auto-dispatch all council agents with proper `thread_root`
3. Auto-read positions after a timeout (e.g., 5 minutes)
4. Auto-synthesize consensus using a dedicated "convergence" agent
5. Auto-create GitHub issues from consensus
6. Auto-close stale issues matching deployed fixes
7. Post converged decision to Matrix

The key pieces that need manual intervention:
- Writing good council questions (context-dependent)
- Reviewing positions before convergence (quality gate)
- Final prioritization judgment (requires human taste)

Everything else can be scripted.

## Notes

- Always use `thread_root` in Matrix posts — without it, messages go to the main room and clutter history
- The council directory path uses `pre-issue` before GitHub issues exist, then moves to `issues/{n}/council/`
- Agent models are in `~/.config/opencode/agents/roles.md` — check current availability before dispatching
- Max 10 parallel agents (cloud capacity), max 3 deliberation rounds