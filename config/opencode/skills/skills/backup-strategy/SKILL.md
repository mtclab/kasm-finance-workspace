---
name: backup-strategy
description: HomePilot backup strategy — database, vault, artifacts, and config backups. Trigger on backup, restore, sqlite, dump, snapshot, disaster recovery, DR, data loss, cron, scheduled. Covers sqlite3 backup, vault backup, artifact archival, and full system restore.
---

# Backup Strategy

Implement and manage backups for HomePilot v2 (SQLite database, vault, artifacts, config).

## When to Use

- User mentions backup, restore, disaster recovery, data loss prevention
- Setting up cron jobs for scheduled backups
- Creating backup scripts for SQLite, vault, or artifacts
- Restoring from backup after failure
- Migrating data between environments

## Architecture

HomePilot stores data in:
- **SQLite database**: `/opt/homepilot/repo/data/homepilot.db`
- **Vault**: `/opt/homepilot/repo/data/vault/` (encrypted age files)
- **Artifacts**: `/opt/homepilot/repo/data/artifacts/`
- **Config**: `/opt/homepilot/repo/.env` and `/opt/homepilot/repo/data/`

## Backup Procedures

### Quick Backup (manual)
```bash
ssh bilvi-homepilot@10.96.16.18

# 1. Database backup (hot backup using sqlite3)
docker compose exec backend python -c "
import sqlite3
conn = sqlite3.connect('/home/homepilot/data/homepilot.db')
conn.execute('BEGIN IMMEDIATE')
import shutil
Shutil.copy2('/home/homepilot/data/homepilot.db', f'/home/homepilot/data/backups/homepilot-{date}.db')
conn.rollback()
conn.close()
"

# 2. Vault backup (encrypted already, just tar)
tar czf /tmp/vault-backup-$(date +%Y%m%d).tar.gz -C /opt/homepilot/repo/data/vault .

# 3. Full data backup
tar czf /tmp/homepilot-full-$(date +%Y%m%d).tar.gz \
  -C /opt/homepilot/repo/data .
```

### Scheduled Backup (cron)
```bash
# Add to crontab on dev server
# Daily at 02:00 UTC
0 2 * * * /opt/homepilot/scripts/backup.sh >> /var/log/homepilot-backup.log 2>&1
```

### Backup Script Template
```bash
#!/bin/bash
# /opt/homepilot/scripts/backup.sh
set -euo pipefail

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/opt/homepilot/backups"
DATA_DIR="/opt/homepilot/repo/data"
RETENTION_DAYS=30

mkdir -p "$BACKUP_DIR"

# SQLite hot backup via docker
docker compose -f /opt/homepilot/repo/docker-compose.yml exec -T backend \
  sqlite3 /home/homepilot/data/homepilot.db \
  ".backup /home/homepilot/data/backups/homepilot-$DATE.db"

# Vault + config
tar czf "$BACKUP_DIR/vault-$DATE.tar.gz" -C "$DATA_DIR" vault/

# Artifacts (incremental via find + cpio)
find "$DATA_DIR/artifacts" -mtime -1 -print0 | \
  cpio -o -0 > "$BACKUP_DIR/artifacts-incr-$DATE.cpio"

# Clean old backups
find "$BACKUP_DIR" -mtime +$RETENTION_DAYS -delete

echo "[$DATE] Backup complete"
```

## Restore Procedures

### Database Restore
```bash
ssh bilvi-homepilot@10.96.16.18

# 1. Stop backend
docker compose down

# 2. Restore database
cp /opt/homepilot/backups/homepilot-YYYYMMDD.db /opt/homepilot/repo/data/homepilot.db

# 3. Start backend
docker compose up -d
```

### Vault Restore
```bash
# 1. Stop backend
docker compose down

# 2. Restore vault
tar xzf /opt/homepilot/backups/vault-YYYYMMDD.tar.gz -C /opt/homepilot/repo/data/

# 3. Start backend
docker compose up -d
```

### Full Disaster Recovery
```bash
# 1. Fresh install
git clone https://github.com/mtclab/homepilot-v2.git /opt/homepilot/repo
cd /opt/homepilot/repo

# 2. Restore data
tar xzf /opt/homepilot/backups/homepilot-full-YYYYMMDD.tar.gz -C data/

# 3. Restore .env
cp /opt/homepilot/backups/.env.YYYYMMDD .env
chmod 600 .env

# 4. Run hp init (if vault passphrase missing)
hp init

# 5. Start
docker compose up -d

# 6. Verify
curl http://localhost:8000/health
```

## Failure Modes

- **SQLite locked**: Stop backend before restore, or use `sqlite3 .backup` for hot backup
- **Vault passphrase lost**: Cannot decrypt vault → must regenerate all secrets with `hp init`
- **Disk full**: Check `/opt/homepilot/backups` size, adjust retention
- **Corrupt backup**: Try previous day's backup; keep at least 7 days
- **Docker volume mismatch**: Ensure data dir matches `docker-compose.yml` volume mount