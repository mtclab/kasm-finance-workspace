# Agent Roles & Dispatch Rules

## Models (Ollama cloud, max 10 simultaneous)

### Cloud Models — 12 available, 10 simultaneous max

| # | Model | AA Intelligence | Arena Overall | Arena WebDev | Best Roles |
|---|-------|----------------|---------------|--------------|------------|
| 1 | `glm-5.1:cloud` | 51 | #19 | **#4** | DataEngineer, SecurityAuditor, WebDev Coder |
| 2 | `kimi-k2.6:cloud` | **54** (best open-weights) | **#29** | **#7** | ProductOwner, ProjectManager, CodeReviewer |
| 3 | `kimi-k2.6:cloud` | 39-52 (reasoning) | #27-30 | good | CoreSquad, SystemArchitect, QA |
| 4 | `deepseek-v4-flash:cloud` | 36-47 (reasoning) | #55-61 | good | Navigator, quick triage, Coder-2nd |
| 5 | `deepseek-v3.2:cloud` | — | #74 | moderate | Coder variant, Reviewer backup |
| 6 | `kimi-k2.5:cloud` | — | #43 | moderate | PO backup, planning, reasoning |
| 7 | `glm-5:cloud` | 50 | #33 | moderate | Legacy review, council diversity |
| 8 | `minimax-m2.7:cloud` | 50 | #100 | moderate | InfraOps, DevOpsEngineer |
| 9 | `minimax-m2.5:cloud` | — | #119 | lower | InfraOps backup, capacity planning |
| 10 | `qwen3.5:cloud` | 40-45 | #49-81 | moderate | Council diversity, UXResearcher |
| 11 | `qwen3-coder-next:cloud` | — | #127 | lower | ClientSquad, ToolingSquad (specialized) |
| 12 | `nemotron-3-super:cloud` | 36 | #152 | lower | Council diversity only |

### Local Models (supplementary — single-agent use only, no dispatch)

| Model | Use |
|-------|-----|
| `gemma4:26b` | Quick local queries, no dispatch |
| `gemma4:e4b` | Lightweight local fallback |
| `qwen3.6:35b` | Local coding, no dispatch |
| `qwen3.6:27b` | Local coding, no dispatch |
| `mistral:latest` | Local experimentation |

### Not used as agents (skip)
`nomic-embed-text` (embedding), `rnj-1:8b` (too small), `command-r7b` (too small), `fixt/home-3b-v3` (too small)

## Key Benchmark Insights

- **glm-5.1** is #4 in WebDev globally — outstanding for frontend/UI work and security
- **kimi-k2.6** is the highest-ranked open-weights model overall (#29) and #7 in WebDev — best reasoning
- **kimi-k2.6** dominates coding benchmarks (LiveCodeBench 93.5, Codeforces 3206) — best for pure code
- **kimi-k2.5** is kimi's smaller/faster variant — solid #43 overall, good for planning and PO
- **minimax-m2.7** has strong tool-use scores — ideal for DevOps/infra work
- **minimax-m2.5** is a step down from m2.7 — use as DevOps backup when m2.7 slots are taken
- **nemotron-3-super** and **qwen3-coder-next** rank lower on Arena but add architecture diversity to councils

## The 13 Agent Roles

### Planning & Strategy

| Role | Primary Model | Backup Model | Focus |
|------|--------------|--------------|-------|
| ProductOwner | kimi-k2.6 | kimi-k2.5 | Vision, priorities, acceptance criteria, scope control |
| ProjectManager | kimi-k2.6 | kimi-k2.5 | Milestones, dependencies, risk register, coordination |
| SystemArchitect | kimi-k2.6 | deepseek-v4-flash | System design, APIs, data models, cross-cutting concerns |

### Implementation

| Role | Primary Model | Backup Model | Focus |
|------|--------------|--------------|-------|
| CoreSquad | kimi-k2.6 | deepseek-v4-flash | Backend code, business logic, API endpoints |
| ClientSquad | glm-5.1 | qwen3-coder-next | Frontend, UI, accessibility, Svelte components |
| ToolingSquad | kimi-k2.6 | qwen3-coder-next | CI/CD, test harness, developer tooling |

### Infrastructure & Data

| Role | Primary Model | Backup Model | Focus |
|------|--------------|--------------|-------|
| InfraOps | minimax-m2.7 | minimax-m2.5 | PVE, Docker, Zabbix, LLM ops, hardware, networking |
| DataEngineer | glm-5.1 | deepseek-v3.2 | SQLite, vault, KB, embeddings, migrations, backup |
| Integrator | deepseek-v4-flash | qwen3-coder-next | MCP tools, n8n workflows, Zabbix integration, webhook wiring |

### Quality & Review

| Role | Primary Model | Backup Model | Focus |
|------|--------------|--------------|-------|
| CodeReviewer | kimi-k2.6 | deepseek-v3.2 | Code quality, bugs, style, architectural drift |
| QATester | kimi-k2.6 | qwen3.5 | Test generation, coverage, regression |
| SecurityAuditor | glm-5.1 | deepseek-v3.2 | Threat modeling, secret audit, auth review |
| UXResearcher | glm-5.1 | qwen3.5 | Usability, accessibility (WCAG), user friction |

### Documentation

| Role | Primary Model | Backup Model | Focus |
|------|--------------|--------------|-------|
| Documenter | kimi-k2.5 | deepseek-v3.2 | Auto-docs on every commit/deploy, ADRs, changelogs, API docs |

### Deployment & Operations

| Role | Primary Model | Backup Model | Focus |
|------|--------------|--------------|-------|
| DevOpsEngineer | minimax-m2.7 | minimax-m2.5 | CI/CD, deployment, release management, rollback |

## Dispatch Rules

- Max 10 parallel agents (cloud capacity)
- Planning council: up to 10 agents in parallel (all models as Architect+PO+PM)
- Ranking: up to 7 coder variants in parallel
- Implementation: up to 3-5 issues in parallel, each with own coder + pair-coding slot
- Gates: all 4 (Reviewer + QA + Security + UX) in parallel, plus InfraOps + Integrator when infra/data changes
- Planning agents use `explore` type (read-only)
- Coder agents use `explore` type for research, `general` type for implementation
- Reviewer/QA/Security/UX are `explore` type (read-only)
- InfraOps/Integrator/DataEngineer are `general` type (may need write + run)
- DevOps is `general` type (needs write + run)
- After each coder task, auto-run lint/typecheck
- Commit only when user asks
- Ollama endpoint: `http://open-webui-ollama:11434`

## New Role Dispatch Triggers

| Role | Trigger keywords | Action |
|------|-----------------|--------|
| InfraOps | PVE, proxmox, VM, LXC, docker, container, Zabbix, LLM, GPU, node, storage, Ceph, network | Dispatch with proxmox-ops, docker-stack, llm-ops, zabbix-monitoring skills |
| DataEngineer | sqlite, vault, migration, KB, embeddings, backup, restore, schema, data model | Dispatch with vault-management, backup-strategy skills |
| Integrator | MCP, n8n, webhook, Zabbix template, integration, wiring, SSE, connector, bridge | Dispatch with n8n-workflows, zabbix-setup, proxmox-ops skills |
| Documenter | doc, docs, documentation, README, changelog, ADR, architecture, deploy, release, merge | Dispatch with auto-documentation skill |

## Per-Model Variants (Planning & Review Councils)

| Model | Architect | PO | PM |
|-------|-----------|----|----|
| `kimi-k2.6` | System design, APIs, data models, cross-cutting design. Use Context7 for FastAPI/Pydantic/SQLAlchemy. | Feature priorities, acceptance criteria, user stories. Challenge scope creep. | Milestones, dependencies, risk register. |
| `deepseek-v4-flash` | Quick architectural triage, rapid assessment. | Fast scope assessment, rapid yes/no on edge cases. | Sprint velocity estimates, quick timeline checks. |
| `deepseek-v3.2` | Implementation architecture, module boundaries, feasibility. Challenge designs that don't map to code. | Tech debt, build-vs-buy, feature flags. | Sprint planning, task breakdown, estimates. |
| `kimi-k2.6` | Review architecture, drift detection, refactor proposals. Devil's advocate. | Requirements completeness, gap analysis. Best reasoning model. | Project status, at-risk deliverables. |
| `kimi-k2.5` | Balanced architecture review, consensus-building. | Balanced PO — compromise between extremes. | Balanced PM — realistic timelines. |
| `glm-5.1` | Security architecture, threat modeling, auth boundaries. #4 WebDev. | Security requirements, compliance, threat scenarios. | Security milestones, remediation tracking. |
| `glm-5` | Legacy architecture review, backwards compatibility. | Backwards compatibility priorities, migration strategies. | Migration planning, phased rollout. |
| `minimax-m2.7` | Infra architecture, deployment topology, scaling. Use Context7 for Docker/CI. | Cost analysis, capacity, SLA. | Release coordination, rollback plans. |
| `minimax-m2.5` | Infra backup, secondary deployment review. | Cost monitoring, resource optimization. | Release timeline coordination. |
| `qwen3-coder-next` | Code architecture, design patterns, API ergonomics. | Developer experience, API ergonomics, tooling priorities. | Technical sprint planning, dependency resolution. |
| `qwen3.5` | General architecture, integration patterns, balanced judgment. | User stories, acceptance criteria, balanced prioritization. | Timeline, resource allocation, stakeholder management. |
| `nemotron-3-super` | Governance architecture, policy enforcement, standards. | Stakeholder alignment, priority conflicts, trade-off analysis. | Dependency management, cross-team coordination. |

## Council Compositions

Pick based on request type. With 10 slots, councils can be larger for higher-stakes decisions.

### Full Council (10 voices — major features, architecture changes)
- kimi-k2.6-Architect + kimi-k2.6-PO + kimi-k2.6-PM
- deepseek-v4-flash-Architect + qwen3.5-PO + nemotron-PM
- glm-5.1-Architect + minimax-m2.7-PO + qwen3-coder-next-PM
- kimi-k2.5-PO + deepseek-v3.2-Architect

### Standard Council (5-6 voices — regular features)
- kimi-k2.6-Architect + kimi-k2.6-PO + kimi-k2.6-PM
- glm-5.1-Architect + qwen3.5-PO
- deepseek-v4-flash-Architect

### Bug Fix Council (3-4 voices — targeted fixes)
- kimi-k2.6-Architect + kimi-k2.6-Reviewer
- glm-5.1-Security + deepseek-v4-flash-PM

### Infra Change Council (4-5 voices — deployment, PVE, Docker, Zabbix)
- minimax-m2.7-Architect + kimi-k2.6-PM + qwen3-coder-next-Integrator
- glm-5.1-DataEngineer + deepseek-v4-flash-InfraOps

### Data Change Council (3-4 voices — schema, vault, KB, embeddings)
- glm-5.1-Architect + kimi-k2.6-DataEngineer + kimi-k2.6-Reviewer

### Integration Council (3-4 voices — MCP, n8n, Zabbix, webhooks)
- deepseek-v4-flash-Integrator + kimi-k2.6-Architect + minimax-m2.7-InfraOps

### Scope/Priority Council (4-5 voices)
- kimi-k2.6-PO + kimi-k2.6-PO + qwen3.5-PO + minimax-m2.7-PM

### WebDev Council (4-5 voices — frontend/UI focus)
- glm-5.1-Architect (ranked #4 WebDev globally)
- kimi-k2.6-PO + kimi-k2.6-PM
- qwen3.5-Architect + deepseek-v4-flash-Architect

## Coder Council Compositions (Implementation deliberation)

| Pattern | Models | Slots |
|---------|--------|-------|
| Full Coder Council | kimi-k2.6 + deepseek-v4-flash + deepseek-v3.2 + glm-5.1 + qwen3-coder-next + kimi-k2.6 + | 6-7 |
| Standard Coder Council | kimi-k2.6 + deepseek-v4-flash + qwen3-coder-next + kimi-k2.6 | 4 |
| Quick Coder Council | kimi-k2.6 + deepseek-v4-flash | 2 |
| WebDev Coder Council | glm-5.1 + kimi-k2.6 + kimi-k2.6 + qwen3-coder-next | 4 |
| Infra Coder Council | minimax-m2.7 + kimi-k2.6 + deepseek-v4-flash | 3 |
| Data Coder Council | glm-5.1 + kimi-k2.6 + kimi-k2.6 | 3 |

## Gate Composition (expanded for 12 roles)

### Standard Gate (4 reviewers)
- CodeReviewer + QA + Security + UX

### Infra Gate (6 reviewers — when infra changes are involved)
- CodeReviewer + QA + Security + UX + InfraOps + Integrator

### Data Gate (5 reviewers — when schema/vault/KB changes)
- CodeReviewer + QA + Security + DataEngineer + UX

### Full Gate (7 reviewers — major cross-cutting changes)
- CodeReviewer + QA + Security + UX + InfraOps + DataEngineer + Integrator

## Operational Skills (agent domain knowledge)

| Skill | Purpose | Trigger |
|-------|---------|---------|
| `proxmox-ops` | PVE VM/LXC/node operations | PVE, proxmox, VM, LXC, node, migrate, snapshot |
| `security-audit` | Security hardening, secret rotation | security, audit, hardening, rotate, credential, vault |
| `vault-management` | HomePilot vault (age encryption) | vault, hp vault, passphrase, secret store, bootstrap |
| `zabbix-monitoring` | Zabbix host/template/trigger setup | zabbix, monitoring, alerts, dashboard, metric |
| `backup-strategy` | SQLite/vault/artifact backup & DR | backup, restore, sqlite dump, snapshot, DR, cron |
| `pr-review-merge` | Code review and merge workflow | review PR, merge PR, approve, request changes |
| `deploy` | Deploy HomePilot to dev server | deploy, push, release, rollout, rollback |
| `e2e-test` | Playwright e2e test suite | e2e, playwright, full test suite, browser test |
| `smoke-test` | Quick endpoint health check | smoke test, health check, endpoint verification |
| `hashline` | Hash-anchored edit validation | hashline, anchor edit, verify edit target |
| `inter-agent-messaging` | Direct message between agents | agent clarification, cross-level guidance |
| `skill-creator` | Create new skills | create skill, repeat workflow pattern |
| `skill-optimizer` | Improve existing skills | skill fails, wrong trigger, quality improvement |

### Project-Level Skills (homepilot-agent only)

| Skill | Purpose | Trigger |
|-------|---------|---------|
| `docker-stack` | Docker Compose management, secrets, health | docker, compose, container, stack, n8n |
| `n8n-workflows` | n8n workflow import, MCP config, webhook | n8n, workflow, personal assistant, chat assistant |
| `zabbix-setup` | Zabbix 7.0 deployment, agent2, Matrix alerts | zabbix, monitoring, agent2, dashboard |
| `llm-ops` | Local LLM (Qwen3-14B, BGE-M3), GPU config | LLM, Qwen, llama.cpp, embedding, GPU |
| `voice-pipeline` | Whisper STT + Piper TTS pipeline | voice, whisper, piper, STT, TTS |