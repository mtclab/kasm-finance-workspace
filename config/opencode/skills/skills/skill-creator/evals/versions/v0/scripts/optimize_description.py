#!/usr/bin/env python3
"""
Skill description optimizer — tests trigger accuracy and improves the description field.

Usage:
    python -m scripts.optimize_description <skill-path> [--verbose]

Tests whether the skill's description triggers correctly on relevant prompts
and doesn't trigger on irrelevant ones.
"""

import argparse
import json
import sys
from pathlib import Path


def load_skill(skill_path: Path) -> dict:
    content = (skill_path / "SKILL.md").read_text()
    if not content.startswith("---"):
        return {"frontmatter": {}, "body": content}

    _, fm_str, body = content.split("---", 2)
    frontmatter = {}
    for line in fm_str.strip().split("\n"):
        if ":" in line:
            key, _, val = line.partition(":")
            val = val.strip().strip('"').strip("'")
            frontmatter[key.strip()] = val

    return {"frontmatter": frontmatter, "body": body.strip()}


def test_trigger(description: str, prompt: str) -> bool:
    """Check if skill description keywords match the prompt.

    This is a heuristic check — real trigger testing requires an LLM.
    We check for keyword overlap between description and prompt.
    """
    desc_words = set(description.lower().split())
    prompt_words = set(prompt.lower().split())
    overlap = desc_words & prompt_words
    # Trigger if >30% of prompt keywords appear in description
    return len(overlap) > len(prompt_words) * 0.3 if prompt_words else False


def main():
    parser = argparse.ArgumentParser(description="Optimize skill description")
    parser.add_argument("skill_path", type=Path, help="Path to skill directory")
    parser.add_argument("--verbose", "-v", action="store_true")
    args = parser.parse_args()

    skill_path = args.skill_path.resolve()
    if not (skill_path / "SKILL.md").exists():
        print(f"Error: no SKILL.md found at {skill_path}")
        sys.exit(1)

    skill_data = load_skill(skill_path)
    description = skill_data["frontmatter"].get("description", "")
    name = skill_data["frontmatter"].get("name", skill_path.name)

    trigger_eval = skill_path / "evals" / "trigger-eval.json"
    if not trigger_eval.exists():
        print(f"No trigger-eval.json found at {trigger_eval}")
        print("Create one with 'should_trigger' and 'should_not_trigger' prompt lists:")
        print(json.dumps({
            "skill_name": name,
            "should_trigger": [
                "deploy the new version",
                "push to production",
            ],
            "should_not_trigger": [
                "what time is it",
                "write a python script",
            ],
        }, indent=2))
        sys.exit(1)

    data = json.loads(trigger_eval.read_text())
    should_trigger = data.get("should_trigger", [])
    should_not_trigger = data.get("should_not_trigger", [])

    print(f"Optimizing description for: {name}")
    print(f"Current description: {description}")
    print()

    true_pos = 0
    false_neg = 0
    for prompt in should_trigger:
        triggered = test_trigger(description, prompt)
        if triggered:
            true_pos += 1
        else:
            false_neg += 1
        if args.verbose:
            print(f"  {'✓' if triggered else '✗'} SHOULD trigger: {prompt}")

    false_pos = 0
    true_neg = 0
    for prompt in should_not_trigger:
        triggered = test_trigger(description, prompt)
        if triggered:
            false_pos += 1
        else:
            true_neg += 1
        if args.verbose:
            print(f"  {'✗' if triggered else '✓'} should NOT trigger: {prompt}")

    precision = true_pos / (true_pos + false_pos) if (true_pos + false_pos) > 0 else 0
    recall = true_pos / (true_pos + false_neg) if (true_pos + false_neg) > 0 else 0
    f1 = 2 * precision * recall / (precision + recall) if (precision + recall) > 0 else 0

    print(f"\nTrigger accuracy:")
    print(f"  Precision: {precision:.0%} ({true_pos}/{true_pos + false_pos})")
    print(f"  Recall:    {recall:.0%} ({true_pos}/{true_pos + false_neg})")
    print(f"  F1:        {f1:.0%}")

    if false_neg > 0:
        print("\n↑ Under-triggering! Add these keywords to description:")
        for prompt in should_trigger:
            if not test_trigger(description, prompt):
                keywords = [w for w in prompt.lower().split() if len(w) > 3]
                print(f"  - From '{prompt}': {', '.join(keywords)}")

    if false_pos > 0:
        print("\n↓ Over-triggering! Narrow description scope:")
        for prompt in should_not_trigger:
            if test_trigger(description, prompt):
                print(f"  - False trigger: '{prompt}'")

    if f1 >= 0.8:
        print("\n✓ Description is well-calibrated (F1 >= 0.8)")
    else:
        print(f"\n→ Description needs optimization (F1 = {f1:.0%})")

    return 0 if f1 >= 0.8 else 1


if __name__ == "__main__":
    sys.exit(main())