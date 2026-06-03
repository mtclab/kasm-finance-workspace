---
name: deploy
description: Deploy HomePilot to dev server or rollback a deployment. Trigger on deploy, push, release, rollout, rollback, or version update commands for the HomePilot dev server.
license: MIT
metadata:
  version: "1.1"
  category: deploy
---

# Deploy HomePilot

Deploy a specific version of HomePilot to the development server, or rollback a failed deployment.

## What I Do

- Pull the specified Docker image tag to the dev server
- Restart the container with the new image
- Wait for health check to pass
- Verify the deployed version matches the requested version

## When to Use Me

- "deploy version 2.1.0"
- "push to dev server"
- "roll out the new release"
- "rollback the deployment"
- "update homepilot on dev"

## Steps

### Deploy

1. Run the deploy script with the target version:
   ```bash
   ./scripts/deploy.sh <VERSION>
   ```
   Example: `./scripts/deploy.sh 2.1.0`

### Rollback

2. For rollback:
   ```bash
   ./scripts/deploy.sh --rollback
   ```

### Verify

3. Verify deployment:
   ```bash
   curl -s http://10.96.16.18:8000/health
   ```
   Expected: `{"status":"ok","version":"<VERSION>"}`

## Notes

- Version tag uses NO `v` prefix in GHCR (e.g., `2.1.0`, not `v2.1.0`)
- Server: bilvi-homepilot@homepilot (10.96.16.18)
- Docker Compose project: /opt/homepilot/repo
- Health check: GET /health returns `{"status": "ok", "version": "..."}`

## Failure Modes

- **Image not found**: Check GHCR for the exact tag (no `v` prefix)
- **Health check timeout**: Container may need restart — check `docker compose logs`
- **SSH failure**: Verify server connectivity with `ssh bilvi-homepilot@homepilot`