# Eval-Iterate Loop

The self-learning process for skill creation and optimization.

## Overview

```
Draft → Eval → Iterate → Eval → ... → Converge → Optimize Description → Install
```

## Step-by-Step

### 1. Draft
- Write SKILL.md with frontmatter + instructions
- Include at least 2 concrete examples
- Front-load trigger keywords in description

### 2. Create Evals
- Write evals/evals.json with test prompts
- Each eval has: prompt, expected_output, expectations list
- Write evals/trigger-eval.json with should_trigger / should_not_trigger lists

### 3. Run Evals
```bash
cd ~/.config/opencode/skills/<name>
python scripts/eval_skill.py . --verbose
```

### 4. Analyze
- Pass rate < 0.9 → rewrite SKILL.md instructions
- Pass rate >= 0.9 → proceed to description optimization

### 5. Optimize Description
```bash
python scripts/optimize_description.py . --verbose
```
- F1 >= 0.8 → done
- F1 < 0.8 → add trigger keywords or narrow scope, re-run

### 6. Install & Verify
- Skill is in discovery path already
- Restart opencode session
- Test: say the trigger prompt, verify skill loads

## Convergence Criteria

- **Instructions converged**: eval pass rate >= 0.9
- **Description optimized**: trigger F1 >= 0.8
- **Max iterations**: 5 (then escalate to user)

## History Tracking

Each iteration is recorded in evals/history.json with:
- Version (v0, v1, v2...)
- Parent version
- Pass rate
- Won/lost/neutral vs previous best
- Whether it's the current best

The optimizer always keeps the best-performing version.