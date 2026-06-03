#!/usr/bin/env python3
"""
Skill eval runner — executes skill instructions against test prompts and measures pass rates.

Usage:
    python -m scripts.eval_skill <skill-path> [--iterations 5] [--verbose]

Reads:
    <skill-path>/evals/evals.json — test cases
    <skill-path>/SKILL.md — skill instructions

Writes:
    <skill-path>/evals/history.json — version history with pass rates
"""

import argparse
import json
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


def load_skill(skill_path: Path) -> dict:
    """Parse SKILL.md frontmatter and body."""
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


def load_evals(skill_path: Path) -> list[dict]:
    """Load eval cases from evals/evals.json."""
    evals_file = skill_path / "evals" / "evals.json"
    if not evals_file.exists():
        print(f"No evals found at {evals_file}")
        return []
    data = json.loads(evals_file.read_text())
    return data.get("evals", [])


def load_history(skill_path: Path) -> dict:
    """Load or initialize eval history."""
    history_file = skill_path / "evals" / "history.json"
    if history_file.exists():
        return json.loads(history_file.read_text())
    return {
        "started_at": datetime.now(timezone.utc).isoformat(),
        "skill_name": "",
        "current_best": "v0",
        "iterations": [],
    }


def save_history(skill_path: Path, history: dict) -> None:
    """Save eval history."""
    history_file = skill_path / "evals" / "history.json"
    history_file.parent.mkdir(parents=True, exist_ok=True)
    history_file.write_text(json.dumps(history, indent=2) + "\n")


def backup_skill(skill_path: Path, version: str) -> Path:
    """Create a versioned backup of the skill."""
    evals_dir = skill_path / "evals"
    versions_dir = evals_dir / "versions"
    versions_dir.mkdir(parents=True, exist_ok=True)
    version_dir = versions_dir / version
    if version_dir.exists():
        shutil.rmtree(version_dir)
    shutil.copytree(skill_path, version_dir, ignore=shutil.ignore_patterns("evals", "__pycache__"))
    return version_dir


def run_eval(skill_data: dict, eval_case: dict, verbose: bool = False) -> dict:
    """
    Evaluate a single test case against the skill.

    For now, this is a manual/expert-driven process.
    The script checks structural expectations, not runtime behavior.
    Full eval requires an LLM to simulate skill execution.
    """
    result = {
        "id": eval_case.get("id"),
        "prompt": eval_case.get("prompt"),
        "expectations_met": [],
        "expectations_failed": [],
        "pass_rate": 0.0,
    }

    expectations = eval_case.get("expectations", [])
    if not expectations:
        result["pass_rate"] = 1.0
        return result

    body = skill_data["body"].lower()
    fm = skill_data["frontmatter"]

    for exp in expectations:
        exp_lower = exp.lower()
        exp_key = exp_lower.split(" ")[0] if " " in exp_lower else exp_lower
        key_words = [w for w in exp_lower.split() if len(w) > 3]
        matched = (
            exp_lower in body
            or exp_lower in fm.get("description", "").lower()
            or any(kw in body for kw in key_words)
            or any(kw in fm.get("description", "").lower() for kw in key_words)
        )
        if matched:
            result["expectations_met"].append(exp)
        else:
            result["expectations_failed"].append(exp)

    met = len(result["expectations_met"])
    total = len(expectations)
    result["pass_rate"] = met / total if total > 0 else 0.0

    return result


def main():
    parser = argparse.ArgumentParser(description="Evaluate an OpenCode skill")
    parser.add_argument("skill_path", type=Path, help="Path to skill directory")
    parser.add_argument("--iterations", type=int, default=5, help="Max iterations")
    parser.add_argument("--verbose", "-v", action="store_true", help="Verbose output")
    args = parser.parse_args()

    skill_path = args.skill_path.resolve()
    if not (skill_path / "SKILL.md").exists():
        print(f"Error: no SKILL.md found at {skill_path}")
        sys.exit(1)

    skill_data = load_skill(skill_path)
    evals = load_evals(skill_path)

    if not evals:
        print("No eval cases found. Create evals/evals.json with test cases.")
        print("Example structure:")
        print(json.dumps({
            "skill_name": "my-skill",
            "evals": [
                {
                    "id": 1,
                    "prompt": "deploy version 2.1.0",
                    "expected_output": "Runs deploy.sh with correct tag format",
                    "expectations": [
                        "skill mentions deploy.sh",
                        "skill mentions version tag format",
                    ],
                }
            ],
        }, indent=2))
        sys.exit(1)

    history = load_history(skill_path)
    history["skill_name"] = skill_data["frontmatter"].get("name", skill_path.name)

    version_num = len(history["iterations"])
    version = f"v{version_num}"

    print(f"Evaluating skill: {history['skill_name']}")
    print(f"Version: {version}")
    print(f"Evals: {len(evals)}")
    print()

    backup_skill(skill_path, version)

    results = []
    total_pass = 0
    total_expectations = 0

    for eval_case in evals:
        result = run_eval(skill_data, eval_case, verbose=args.verbose)
        results.append(result)
        total_pass += len(result["expectations_met"])
        total_expectations += len(eval_case.get("expectations", []))

        if args.verbose:
            status = "PASS" if result["pass_rate"] >= 1.0 else "FAIL"
            print(f"  Eval {result['id']}: {status} ({result['pass_rate']:.0%})")
            for exp in result["expectations_met"]:
                print(f"    ✓ {exp}")
            for exp in result["expectations_failed"]:
                print(f"    ✗ {exp}")

    pass_rate = total_pass / total_expectations if total_expectations > 0 else 0.0
    print(f"\nOverall pass rate: {pass_rate:.0%} ({total_pass}/{total_expectations})")

    is_best = pass_rate > (
        max(
            (it.get("expectation_pass_rate", 0) for it in history["iterations"]),
            default=0,
        )
    )

    iteration = {
        "version": version,
        "parent": history.get("current_best"),
        "expectation_pass_rate": pass_rate,
        "grading_result": "baseline" if version_num == 0 else ("won" if is_best else "lost"),
        "is_current_best": is_best,
    }
    history["iterations"].append(iteration)

    if is_best:
        history["current_best"] = version

    save_history(skill_path, history)

    print(f"\nIteration {version}: {'WON — new best!' if is_best else 'LOST — previous best remains'}")
    print(f"Current best: {history['current_best']}")

    if pass_rate >= 0.9:
        print("\n✓ Converged! Pass rate >= 0.9")
    elif version_num >= args.iterations - 1:
        print(f"\n✗ Max iterations ({args.iterations}) reached without convergence.")
        print("Escalate: review the skill manually or adjust evals.")
    else:
        print("\n→ Rewrite the skill and re-run eval to continue iteration.")

    return 0 if pass_rate >= 0.9 else 1


if __name__ == "__main__":
    sys.exit(main())