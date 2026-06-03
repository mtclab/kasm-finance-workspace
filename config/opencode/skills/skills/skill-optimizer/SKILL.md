---
name: skill-optimizer
description: Improve existing OpenCode skills based on failure patterns, usage feedback, and eval results. Trigger when a skill produces incorrect output, fails to trigger on relevant prompts, triggers on irrelevant prompts, or when user reports a skill issue. Iteratively improves skill quality through measured eval loops.
license: MIT
metadata:
  version: "1.0"
  category: meta
  self_learning: true
---

# Skill Optimizer

Improve existing OpenCode skills through measured iteration. This is the **self-learning** companion to `skill-creator` — it takes an existing skill and makes it better based on evidence.

## When to Use

- A skill fails to trigger when it should (under-triggering)
- A skill triggers on irrelevant prompts (over-triggering)
- A skill produces incorrect or incomplete output
- User reports "the X skill didn't work right"
- After a significant project change (new commands, paths, APIs)

## Process

### Phase 1: Diagnose

1. Read the current skill:
   ```bash
   cat ~/.config/opencode/skills/<name>/SKILL.md
   # or
   cat .opencode/skills/<name>/SKILL.md
   ```

2. Identify the failure mode:
   - **Under-trigger**: skill not activating → description needs more keywords
   - **Over-trigger**: skill activating on unrelated prompts → description needs scoping
   - **Wrong output**: skill activates but steps are wrong → instructions need fixing
   - **Stale**: commands/paths changed → update steps and scripts
   - **Missing context**: skill assumes knowledge not present → add references

3. Read existing eval history (if any):
   ```bash
   cat <skill-path>/evals/history.json
   ```

### Phase 2: Create/Update Evals

1. If no evals exist, create `<skill-path>/evals/evals.json`:
   - Include the **failing scenario** as the first eval
   - Add 2-3 more scenarios covering the skill's intended scope
   - Each eval has: prompt, expected_output, expectations list

2. If evals exist, add the **failing scenario** as a new eval entry

3. Run the current skill against all evals and record baseline pass rate

### Phase 3: Iterate

1. Rewrite the skill based on diagnosis:
   - **Under-trigger**: add trigger keywords to description, add "When to use me" examples
   - **Over-trigger**: narrow description scope, add "When NOT to use me" section
   - **Wrong output**: fix specific steps, add error handling, clarify ambiguous instructions
   - **Stale**: update commands, paths, versions, URLs
   - **Missing context**: add references/, scripts/, or inline explanations

2. Version the update in history.json:
   ```json
   {
     "version": "v{N+1}",
     "parent": "v{N}",
     "expectation_pass_rate": <measured>,
     "grading_result": "won|lost|neutral",
     "is_current_best": <true if best so far>
   }
   ```

3. Re-run evals, record pass rate

4. Repeat until:
   - Pass rate >= 0.9
   - OR 5 iterations reached without improvement → escalate to user

### Phase 4: Optimize Description

After instructions converge, optimize the `description` field:

1. List 5-10 phrases a user might say that should trigger this skill
2. List 5 phrases that should NOT trigger this skill
3. Test trigger accuracy against both lists
4. Refine description to maximize true positives and minimize false positives
5. Front-load keywords and filenames users are likely to mention

### Phase 5: Propagate

1. Write the updated skill
2. If global skill changed: update `~/.config/opencode/skills/<name>/SKILL.md`
3. If project skill changed: update `.opencode/skills/<name>/SKILL.md`
4. If bundled scripts changed: update `<skill-path>/scripts/`
5. Verify: restart opencode session, confirm updated skill loads

## Self-Learning Rules

- **Failure-driven**: only optimize when there's evidence of a problem (eval failure or user report)
- **Metric-driven**: every change must improve the eval pass rate
- **Conservative**: preserve what works, only change what's broken
- **Versioned**: history.json tracks every iteration with pass rates
- **Convergence**: 0.9 pass rate OR 5 iterations → stop

## Example: Optimizing the Deploy Skill

```
User: "The deploy skill didn't use the right image tag format"

1. Diagnose: skill says "2.1.0" but GHCR uses "2.1.0" (no v prefix) → stale output
2. Eval: add "deploy v2.2.0" → expected: correct tag format without v prefix
3. Iterate: update SKILL.md steps, add note about tag format
4. Verify: re-run evals, pass rate 1.0
5. Propagate: commit updated skill
```