---
name: security-audit
description: Security audit and hardening for HomePilot infrastructure. Trigger on security, audit, hardening, secrets, vault, rotate, token rotation, credential, CVE, vulnerability, compliance, PCI, zero-trust, passphrase. Covers secret rotation, vault integrity, .env hardening, token lifecycle, CSRF/XSS review.
---

# Security Audit & Hardening

Perform security audits and implement hardening for HomePilot v2 and related infrastructure.

## When to Use

- User mentions security audit, hardening, secrets rotation, credential management
- Reviewing token/auth security, CSRF, XSS vulnerability scan
- Rotating secrets (admin tokens, vault passphrase, PVE tokens)
- Hardening .env files, Docker containers, network access
- Checking for exposed secrets in git history
- Compliance requirements (PCI, SOC2, zero-trust)

## Steps

1. **Inventory secrets**: Identify all secrets in `.env`, vault, code, and git history
2. **Check .env permissions**: Must be 0600, no secrets in version control
3. **Rotate compromised secrets**: Use `hp vault set` for runtime secrets, regenerate admin tokens
4. **Verify vault integrity**: `hp vault get <key>` for each stored secret
5. **Audit code paths**: Review auth middleware, CSRF enforcement, token validation
6. **Audit network**: Firewall rules, exposed ports, TLS config
7. **Document findings**: Update `docs/deployment.md` security checklist

## Key Operations

### Secret Rotation Workflow
```bash
# On dev server (10.96.16.18):
ssh bilvi-homepilot@10.96.16.18

# 1. Generate new secrets
NEW_SECRET=$(openssl rand -hex 32)
NEW_KEY=$(openssl rand -hex 32)
NEW_PASSPHRASE=$(openssl rand -hex 32)

# 2. Rotate vault
cd /opt/homepilot/repo
hp vault delete secret-key 2>/dev/null || true
echo "{\"key\": \"$NEW_KEY\"}" | hp vault set secret-key
hp vault delete admin-secret 2>/dev/null || true
echo "{\"secret\": \"$NEW_SECRET\"}" | hp vault set admin-secret

# 3. Update .env (remove old secrets, add new passphrase)
sed -i "s/HP_VAULT_PASSPHRASE=.*/HP_VAULT_PASSPHRASE=$NEW_PASSPHRASE/" .env

# 4. Recreate container
docker compose down && docker compose up -d

# 5. Verify
curl -s http://localhost:8000/health
```

### Token Audit
```bash
# List tokens
curl -s -H "x-hp-admin-secret: $ADMIN_SECRET" http://localhost:8000/auth/tokens | jq

# Delete old tokens
curl -X DELETE -H "x-hp-admin-secret: $ADMIN_SECRET" \
  http://localhost:8000/auth/tokens/hp_OLD_PREFIX

# Create new admin token
curl -X POST -H "x-hp-admin-secret: $ADMIN_SECRET" \
  -d '{"label": "admin-$(date +%Y%m%d)", "scope": "full"}' \
  http://localhost:8000/auth/tokens
```

### Git History Cleanse
```bash
# Check for leaked secrets
git log --all --oneline -- '*.env' '*secret*' '*password*' '*token*'
# If found: use git-filter-repo or BFG to purge
```

## Security Checklist

- [ ] `.env` permissions 0600, no secrets committed to git
- [ ] Vault passphrase stored in mode-600 file, not in `.env` plaintext
- [ ] Admin tokens use 16-char prefix (`PREFIX_LENGTH=16`)
- [ ] CSRF enforcement only in `auth/deps.py`, not in rate-limit middleware
- [ ] All test tokens deleted from production DB
- [ ] Docker container runs as non-root user
- [ ] Health endpoint has no auth requirement
- [ ] PVE API token stored in vault, not hardcoded
- [ ] Webhook secrets rotated and stored in vault
- [ ] Jumpserver auth token stored in vault

## Failure Modes

- **Vault locked**: Wrong passphrase → reinitialize with `hp init`
- **Token invalid after rotation**: Regenerate using admin secret header
- **Container won't start**: Check `.env` syntax, vault passphrase match
- **Secrets in git**: Use `git filter-repo` to purge, never force-push shared branches