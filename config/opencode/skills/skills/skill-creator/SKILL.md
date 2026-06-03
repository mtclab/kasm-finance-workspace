---
name: skill-creator
description: Create, evaluate, and iterate on new OpenCode skills. Trigger when user asks to create a skill, when a repetitive workflow pattern is identified that should be captured as a skill, or when improving an existing skill based on failure or feedback. Self-learning: uses eval-iterate loop to converge on high-quality skills.
license: MIT
metadata:
  version: "1.0"
  category: meta
  self_learning: true
---

# Skill Creator

Create new OpenCode skills through a structured draft → eval → iterate loop. This skill is **self-learning**: it evaluates its own output and rewrites until quality converges.

## When to Use

- User asks "create a skill for X"
- A workflow pattern repeats 2+ times and should be captured
- An existing skill fails or produces poor results (use skill-optimizer instead for incremental improvements)
- New project capability discovered that agents should know about

## Process

### Phase 1: Discover

1. Ask: "What should this skill do? When should it trigger?"
2. Identify the **trigger condition** — what user request or context activates this skill?
3. Identify the **outcome** — what does a successful skill invocation produce?
4. Check if a similar skill already exists:
   - `ls ~/.config/opencode/skills/*/SKILL.md`
   - `ls .opencode/skills/*/SKILL.md`
   - If similar, consider extending or modifying the existing skill instead.

### Phase 2: Draft

1. Create the skill directory structure:
   ```
   <skill-path>/
   ├── SKILL.md          (required — frontmatter + instructions)
   ├── scripts/           (optional — executable helpers)
   ├── references/        (optional — docs loaded into context)
   └── assets/            (optional — templates, configs)
   ```

2. Write `SKILL.md` with:
   - **YAML frontmatter**: `name`, `description` (min 20 chars, front-load trigger keywords), optional `license`, `metadata`
   - **What I do**: clear statement of capability
   - **When to use me**: trigger conditions with keywords users are likely to say
   - **Steps**: numbered, deterministic, with exact commands
   - **Examples**: at least 2 concrete usage examples
   - **Failure modes**: what can go wrong and how to recover

3. The `description` field is critical — it's the primary mechanism for skill discovery. Make it:
   - Proactive (trigger on relevant contexts even if not explicitly requested)
   - Keyword-rich (include filenames, commands, and domain terms users would mention)

### Phase 3: Evaluate

1. Create an eval set in `<skill-path>/evals/evals.json`:
   ```json
   {
     "skill_name": "<name>",
     "evals": [
       {
         "id": 1,
         "prompt": "<what user would say>",
         "expected_output": "<what skill should produce>",
         "expectations": [
           "Output includes X",
           "Skill used script Y"
         ]
       }
     ]
   }
   ```

2. For each eval:
   - Run the skill manually (simulate the steps)
   - Check if output meets expectations
   - Record pass/fail

3. Create `<skill-path>/evals/history.json`:
   ```json
   {
     "started_at": "<ISO8601>",
     "skill_name": "<name>",
     "current_best": "v0",
     "iterations": [
       {
         "version": "v0",
         "parent": null,
         "expectation_pass_rate": <0.0-1.0>,
         "grading_result": "baseline",
         "is_current_best": true
       }
     ]
   }
   ```

### Phase 4: Iterate

1. If pass rate < 0.9:
   - Analyze failures — which expectations failed and why
   - Rewrite the SKILL.md instructions to address failures
   - Re-run eval set
   - Record iteration in history.json
2. Repeat until pass rate >= 0.9 or 5 iterations reached
3. After skill instructions converge, run the **description optimizer**:
   - Test trigger accuracy: does the skill activate on relevant prompts?
   - Refine the `description` field to improve discovery
   - Add keywords from failed-trigger scenarios

### Phase 5: Install

1. Global skills: `~/.config/opencode/skills/<name>/SKILL.md`
2. Project-local skills: `.opencode/skills/<name>/SKILL.md`
3. Verify discovery: restart opencode session, confirm skill appears in `skill` tool

## Self-Learning Rules

- **Capture patterns**: When you see a user repeat a workflow 2+ times, propose creating a skill
- **Learn from failure**: When a skill fails to trigger or produces bad output, create an eval, iterate, and update
- **Track versions**: Every iteration gets a version in `history.json`
- **Convergence criteria**: Pass rate >= 0.9 AND description triggers correctly on 3/3 test prompts
- **Max iterations**: Stop after 5 if not converging — escalate to user

## Existing Skills Pattern

The HomePilot project uses flat `.md` files in `~/.config/opencode/skills/`. The directory-based format (`<name>/SKILL.md`) is the Anthropic Skills Specification v1.0 standard and is preferred for new skills. Both formats work with OpenCode.

When creating project-specific skills, place them in `<project-root>/.opencode/skills/<name>/SKILL.md`.

## Example: Creating a Deploy Skill

```
User: "Create a skill for deploying HomePilot"

1. Discover: trigger = "deploy", outcome = "pushed image + health check green"
2. Draft: .opencode/skills/deploy/SKILL.md with steps, scripts, and examples
3. Eval: prompts like "deploy version 2.2.0" → should produce correct deploy commands
4. Iterate: if eval fails (e.g., forgot version format), update skill
5. Install: verified in skill discovery
```

## Failure Modes

- **Under-triggering**: skill doesn't activate on relevant prompts → improve description keywords
- **Over-triggering**: skill activates on unrelated prompts → narrow description scope
- **Stale instructions**: commands or paths changed → update steps and re-eval
- **Missing context**: skill assumes knowledge not in instructions → add references/