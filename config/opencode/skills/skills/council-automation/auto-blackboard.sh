#!/bin/bash
# auto-blackboard.sh — generates blackboard.md from repo state
# Usage: auto-blackboard.sh [issue_description]
set -e

REPO=/home/kasm-user/repot/homepilot-v2
AGENT_REPO=/home/kasm-user/repot/homepilot-agent
BLACKBOARD=/tmp/opencode/issues/pre-issue/blackboard.md
DATE=$(date +%Y-%m-%d)

mkdir -p /tmp/opencode/issues/pre-issue/council

echo "# Blackboard: Next Features & Priorities ($DATE)" > "$BLACKBOARD"
echo "" >> "$BLACKBOARD"
echo "## Current State" >> "$BLACKBOARD"
echo "" >> "$BLACKBOARD"

# homepilot-v2
HP_VERSION=$(grep 'version =' "$REPO/pyproject.toml" 2>/dev/null | head -1 | cut -d'"' -f2 || echo "unknown")
HP_DEPLOYED=$(curl -sf http://10.96.16.18:8000/health 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin).get('version','unknown'))" 2>/dev/null || echo "unreachable")
HP_ISSUES=$(cd "$REPO" && gh issue list --repo mtclab/homepilot-v2 --state open 2>/dev/null | wc -l || echo "?")
HP_COMMIT=$(cd "$REPO" && git log --oneline -1 2>/dev/null || echo "unknown")

echo "### homepilot-v2 (v${HP_VERSION})" >> "$BLACKBOARD"
echo "- Deployed: ${HP_DEPLOYED}" >> "$BLACKBOARD"
echo "- Open issues: ${HP_ISSUES}" >> "$BLACKBOARD"
echo "- Latest commit: ${HP_COMMIT}" >> "$BLACKBOARD"
echo "- Stack: Python/FastAPI backend, SvelteKit frontend, SQLite/WAL, MCP server, n8n integration" >> "$BLACKBOARD"
echo "" >> "$BLACKBOARD"

# homepilot-agent
AGENT_COMMIT=$(cd "$AGENT_REPO" && git log --oneline -1 2>/dev/null || echo "unknown")
echo "### homepilot-agent" >> "$BLACKBOARD"
echo "- Latest commit: ${AGENT_COMMIT}" >> "$BLACKBOARD"
echo "- Stack: llama.cpp (Qwen3-14B Q8_0), n8n workflows, SearXNG, Radicale" >> "$BLACKBOARD"
echo "- 5 n8n workflows: personal-assistant, artifact-notification, chat-assistant, morning-briefing, calendar-trigger" >> "$BLACKBOARD"
echo "- Agent tiers: HomePilot (IaC), opencode orchestra (dev agents via PR), n8n (personal agent + notifications)" >> "$BLACKBOARD"
echo "- MCP tools: query_inventory, get_environment_doc, search_kb, record_fact, propose_artifact" >> "$BLACKBOARD"
echo "- 3× RTX 4000 Ada SFF GPUs, GPU 0 active for LLM" >> "$BLACKBOARD"
echo "" >> "$BLACKBOARD"

# Open issues
echo "## Open Issues" >> "$BLACKBOARD"
cd "$REPO" && gh issue list --repo mtclab/homepilot-v2 --state open 2>/dev/null >> "$BLACKBOARD" || echo "(could not fetch)" >> "$BLACKBOARD"
echo "" >> "$BLACKBOARD"

# Custom question from arg
if [ -n "$1" ]; then
    echo "## User Request" >> "$BLACKBOARD"
    echo "$1" >> "$BLACKBOARD"
    echo "" >> "$BLACKBOARD"
fi

echo "## Questions for Council" >> "$BLACKBOARD"
echo "1. What's the highest-value next feature?" >> "$BLACKBOARD"
echo "2. Should homepilot-agent get deeper integration?" >> "$BLACKBOARD"
echo "3. Any remaining bugs before new features?" >> "$BLACKBOARD"
echo "4. Security concerns?" >> "$BLACKBOARD"
echo "5. GPU utilization — worth expanding?" >> "$BLACKBOARD"

echo "Blackboard written to $BLACKBOARD"
