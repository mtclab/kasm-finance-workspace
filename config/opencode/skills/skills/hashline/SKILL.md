---
name: hashline
description: Hash-anchored edit validation. Prepend edit operations with line hash verification to prevent stale-line edit failures. Trigger on "hashline", "anchor edit", "verify edit target".
metadata:
  version: "0.1"
  category: quality
---

# Hashline Skill

Prevent stale-line edit failures by anchoring edit operations to content hashes.

## Pattern

Every file line can be fingerprinted by hashing its stripped content. When an agent reads a file, it should run `hashline.sh` to obtain the hash map. Before issuing an `edit` call, the agent verifies the target line's hash still matches. If the hash diverges, the agent must re-read the file before editing.

## Hash Computation

- Strip trailing whitespace from each line
- Blank lines: hash = `-`
- Non-blank lines: first 8 chars of `md5sum` of stripped content
- Format: `LINE_NUM  HASH_ID  CONTENT_PREVIEW`

## Agent Workflow

1. **Read** the target file
2. **Run** `bash scripts/hashline.sh <filepath>` to get the hash map
3. **Before editing**, re-run `hashline.sh` and confirm the target line's hash matches the one from step 2
4. If hash matches → proceed with `edit`
5. If hash differs → re-read the file, update hash map, then edit

## Usage

```bash
bash /home/kasm-user/.config/opencode/skills/skills/hashline/scripts/hashline.sh <filepath>
```

Output example:

```
42  a3f2c1d9  def create_app_state(settings
43  -          (empty line)
44  7b1e0f3a      return AppState(config=cfg, db=db
```

## Integration with Edit Tool

Before calling `edit` with an `oldString` that targets a specific line:

1. Record the hash of the target line from your initial read
2. Immediately before the edit, run `hashline.sh` again
3. If `HASH_ID` changed → file was modified, re-read before editing
4. If `HASH_ID` unchanged → safe to edit