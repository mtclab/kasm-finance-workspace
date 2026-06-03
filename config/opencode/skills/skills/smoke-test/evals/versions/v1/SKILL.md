---
name: smoke-test
description: Run quick smoke test against live HomePilot instance to verify all endpoints work. Trigger on smoke test, quick check, endpoint verification, health check against live server.
license: MIT
metadata:
  version: "1.1"
  category: test
---

# Smoke Test HomePilot

Run a quick smoke test against a live HomePilot instance to verify all endpoints work.

## What I Do

- Check health endpoint
- Verify authenticated API calls (artifacts, inventory, drift, kb)
- Test reconciler endpoints (inventory refresh)
- Verify MCP endpoint is reachable

## When to Use Me

- "run smoke test"
- "quick check the server"
- "verify endpoints work"
- "health check against live"
- "are all endpoints up"

## Steps

1. Set environment variables:
   ```bash
   export HP_TEST_URL=http://10.96.16.18:8000
   export HP_TEST_TOKEN=hp_765a64474e0cc77f52ce64608e58bb3d8f73f0bc6bbbb48ab9861ff5210dc6ed
   ```

2. Run the smoke test:
   ```bash
   ./scripts/smoke-test.sh
   ```
   Or with explicit args: `./scripts/smoke-test.sh <URL> <TOKEN>`

3. Expected: 7/7 checks pass (health, artifacts, inventory, drift, kb, refresh, MCP)

## Notes

- Token and URL can also be passed as arguments: `./scripts/smoke-test.sh <URL> <TOKEN>`
- Drift refresh check may be slow if Proxmox is reachable (30+ seconds)
- MCP endpoint returns 404 (uses SSE transport) — this is expected and passes the check

## Failure Modes

- **401 errors**: Token expired or incorrect
- **Connection refused**: Server not running or wrong URL
- **MCP 404**: Expected behavior for SSE transport, not a real failure