# Skill Specification Reference

Based on Anthropic Skills Specification v1.0 and OpenCode skill discovery.

## Directory Structure

```
~/.config/opencode/skills/<name>/     # Global skills
.opencode/skills/<name>/              # Project-local skills (overrides global)
├── SKILL.md               (required)  # YAML frontmatter + Markdown instructions
├── scripts/               (optional)  # Executable helpers
│   └── *.py, *.sh
├── references/            (optional)  # Docs loaded into context
│   └── *.md, *.txt
├── assets/                (optional)  # Templates, configs
│   └── *.*
└── evals/                 (optional)  # Evaluation framework
    ├── evals.json          # Test cases
    ├── trigger-eval.json   # Trigger accuracy tests
    ├── history.json         # Version history with pass rates
    └── versions/            # Versioned backups
```

## SKILL.md Format

```markdown
---
name: my-skill                    # Must match directory name
description: What this skill does AND when to trigger (min 20 chars)
license: MIT                      # Optional
metadata:                         # Optional
  version: "1.0"
  category: deploy
  self_learning: false
---

# Skill Title

## What I Do
Clear statement of capability.

## When to Use Me
Trigger conditions with keywords users are likely to say.

## Steps
1. Step one with exact commands
2. Step two
3. Verification step

## Examples
- Example usage 1
- Example usage 2

## Failure Modes
- What can go wrong and how to recover
```

## Discovery Order (Later overrides earlier)

1. `~/.config/opencode/skills/*/SKILL.md` (XDG config)
2. `~/.opencode/skills/*/SKILL.md` (global)
3. `$OPENCODE_CONFIG_DIR/skills/*/SKILL.md` (custom config)
4. `.opencode/skills/*/SKILL.md` (project-local, highest priority)

Also discovers flat `.md` files in these directories for backward compatibility.

## Flat vs Directory Format

- **Flat**: `skills/deploy.md` — simple, works, no bundled resources
- **Directory**: `skills/deploy/SKILL.md` — supports scripts/, references/, evals/
- Both formats work with OpenCode's `skill` tool
- Directory format is preferred for skills with evals or helper scripts

## Self-Learning Evals

### evals.json Schema

```json
{
  "skill_name": "my-skill",
  "evals": [
    {
      "id": 1,
      "prompt": "What user would say",
      "expected_output": "What skill should produce",
      "files": [],
      "expectations": [
        "Output includes X",
        "Skill used script Y"
      ]
    }
  ]
}
```

### trigger-eval.json Schema

```json
{
  "skill_name": "my-skill",
  "should_trigger": ["deploy version 2.1", "push to dev server"],
  "should_not_trigger": ["what time is it", "write a python script"]
}
```

### history.json Schema

```json
{
  "started_at": "2026-05-11T...",
  "skill_name": "my-skill",
  "current_best": "v1",
  "iterations": [
    {
      "version": "v0",
      "parent": null,
      "expectation_pass_rate": 0.65,
      "grading_result": "baseline",
      "is_current_best": false
    },
    {
      "version": "v1",
      "parent": "v0",
      "expectation_pass_rate": 0.9,
      "grading_result": "won",
      "is_current_best": true
    }
  ]
}
```

## Description Optimization

The `description` field is the primary discovery mechanism. Rules:

1. **Front-load keywords**: Put the most important trigger words first
2. **Include filenames**: If the skill operates on specific files, name them
3. **Include commands**: If it runs specific commands, name them
4. **Be proactive**: "Trigger when X" not "A skill for X"
5. **Min 20 chars**: Below this, discovery quality degrades