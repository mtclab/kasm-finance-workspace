---
name: vault-management
description: Manage HomePilot vault — encrypted secret storage using age encryption. Trigger on vault, secret store, hp vault, passphrase, encrypt secret, age, trust anchor, bootstrap secrets. Covers hp init, hp vault set/get/delete/list, two-phase bootstrap, zero-secrets deployment.
---

# Vault Management

Manage the HomePilot encrypted vault for storing runtime secrets.

## When to Use

- User mentions vault, secrets storage, `hp vault`, passphrase, trust anchor
- Bootstrapping a new deployment with `hp init`
- Storing/rotating/retrieving secrets like PVE tokens, webhook secrets, admin tokens
- Moving from `.env` secrets to vault-managed secrets
- Zero-secrets deployment setup

## Architecture

HomePilot vault uses age encryption (AES-256-GCM) with a passphrase-derived key:
- Passphrase → Scrypt → age key
- `master.protected` = encrypted age identity
- Secrets stored as `<key>.age` files in `~/.hp/vault/`
- Vault passphrase file: `HP_VAULT_PASSPHRASE_FILE` (default: `/run/secrets/vault_passphrase`)

### Two-Phase Bootstrap
1. **Minimal phase**: `app_state.py` reads `HP_VAULT_PASSPHRASE_FILE` → inits vault
2. **Secret phase**: After vault init, reads `secret-key`, `admin-secret` from vault; auto-generates if missing

### Zero-Secret `.env`
Only non-secret config in `.env`:
```env
HP_DAEMON_PORT=8000
HP_PROXMOX_HOST=pve.lan
HP_VAULT_PASSPHRASE_FILE=/run/secrets/vault_passphrase
HP_LOG_LEVEL=info
# All secrets managed by vault — run `hp init`
```

## CLI Commands

### Initialize vault on fresh deployment
```bash
hp init
# → generates passphrase, stores in HP_VAULT_PASSPHRASE_FILE (mode 600)
# → initializes vault, generates secret-key + admin-secret
# → prints admin secret ONCE
```

### Store secrets
```bash
hp vault set pve-token
# → Enter JSON: {"token": "homepilot@pve!homepilot=..."}

hp vault set jumpserver-token
# → Enter JSON: {"token": "9e96e4af..."}

hp vault set webhook-secret
# → Enter JSON: {"secret": "cbed598b..."}

hp vault set secret-key
# → Enter JSON: {"key": "a1b2c3d4..."}

hp vault set admin-secret
# → Enter JSON: {"secret": "QNnONhnjK-..."}
```

### Retrieve secrets
```bash
hp vault get pve-token        # → {"token": "homepilot@pve!..."}
hp vault list                  # → lists all stored keys
```

### Delete secrets
```bash
hp vault delete old-token
```

## Runtime Behavior (app_state.py)

```python
# Order of precedence for each secret:
# 1. Vault (encrypted, preferred)
# 2. Environment variable (fallback, deprecated for secrets)
# 3. Auto-generated (first boot only, stored to vault)

# PVE token: vault key "pve-token", field "token"
# Secret key: vault key "secret-key", field "key"
# Admin secret: vault key "admin-secret", field "secret"
# Jumpserver token: vault key "jumpserver-token", field "token"
# Webhook secret: vault key "webhook-secret", field "secret"
```

## Rotation Procedure

```bash
# 1. Generate new value
NEW_SECRET=$(openssl rand -hex 32)

# 2. Store in vault (overwrites old)
echo "{\"secret\": \"$NEW_SECRET\"}" | hp vault set admin-secret

# 3. Restart service
docker compose restart backend

# 4. Verify
curl -s -H "x-hp-admin-secret: $NEW_SECRET" http://localhost:8000/auth/tokens
```

## Failure Modes

- **Wrong passphrase**: Vault init fails → check `HP_VAULT_PASSPHRASE_FILE` contents
- **Vault locked/corrupt**: Delete `master.protected`, re-run `hp init` (generates new keys, old secrets lost)
- **Secret not found**: Falls back to env var, then auto-generates and stores
- **Permission denied**: `chmod 600` on passphrase file
- **Docker secret mount**: Ensure `/run/secrets/vault_passphrase` is mounted in compose