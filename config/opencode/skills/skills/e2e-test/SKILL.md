---
name: e2e-test
description: Run full Playwright e2e test suite against live HomePilot including reconciler tests and UI screenshots. Trigger on e2e, end-to-end test, playwright test, full test suite, browser test against live server.
license: MIT
metadata:
  version: "1.1"
  category: test
---

# Run E2E Tests Against Live Server

Run the full Playwright e2e test suite against a live HomePilot instance, including reconciler-specific tests and UI screenshots.

## What I Do

- Run 18 Playwright tests against live HomePilot
- Cover auth, API health, UI pages, reconciler endpoints, drift UI, token creation, rate limiting
- Capture browser screenshots for visual verification
- Verify all reconciler endpoints and UI pages work end-to-end

## When to Use Me

- "run e2e tests"
- "end-to-end test"
- "playwright test"
- "full test suite"
- "browser test against live server"
- "verify the UI works"

## Steps

1. Set environment variables:
   ```bash
   export HP_TEST_URL=http://10.96.16.18:8000
   export HP_TEST_TOKEN=hp_765a64474e0cc77f52ce64608e58bb3d8f73f0bc6bbbb48ab9861ff5210dc6ed
   ```

2. Run e2e tests:
   ```bash
   ./scripts/e2e-test.sh
   ```
   Or directly:
   ```bash
   HP_TEST_URL=http://10.96.16.18:8000 HP_TEST_TOKEN=hp_... pytest tests/test_e2e.py -v
   ```

3. Check screenshots in `screenshots/` directory for UI visual verification.

## Reconciler-specific Tests

- `test_drift_endpoint_returns_items` — GET /artifacts/drift
- `test_inventory_refresh_returns_host_ids` — POST /inventory/refresh (needs Proxmox)
- `test_drift_refresh_endpoint` — GET /artifacts/drift?refresh=true
- `test_drift_page_loads` — UI /ui/drift renders without auth errors
- `test_settings_page_shows_session` — UI /ui/settings shows session info

## Failure Modes

- **429 rate limiting**: Tests order matters — reconciler UI tests run before rate-limit tests
- **Auth page fixture**: Retries login on 429 with exponential backoff
- **Playwright not found**: Install with `pip install playwright && playwright install chromium`
- **Server down**: Verify with `curl http://10.96.16.18:8000/health`