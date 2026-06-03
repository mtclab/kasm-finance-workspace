---
name: proxmox-ops
description: Proxmox VE operations via MCP tools. Trigger on PVE, proxmox, VM, LXC, container, node, storage, cluster, migration, snapshot, backup, firewall, network, SDN, Ceph tasks. Covers create, config, migrate, snapshot, destroy VMs/LXCs and node management.
---

# Proxmox Operations

Operate Proxmox VE clusters and guests using the Proxmox MCP tools.

## When to Use

- User mentions PVE, Proxmox, VMs, LXCs, nodes, storage, Ceph, SDN, firewall
- Creating, configuring, migrating, snapshotting, or destroying virtual infrastructure
- Checking cluster health, node status, resource usage
- Managing Ceph pools, OSDs, monitors

## Steps

1. **Identify target**: Use `proxmox_proxmox_list_nodes` to find nodes, `proxmox_proxmox_list_vms`/`proxmox_proxmox_list_lxc` for guests
2. **Gather state**: Use read-only tools (`_info`, `_status`, `_config`) before any mutation
3. **Execute operation**: Use elevated tools with `confirm=true` for destructive/mutating actions
4. **Verify**: Re-read state after operation to confirm success
5. **Report**: Summarize what changed

## Key Patterns

### VM/LXC Lifecycle
- Create: `proxmox_proxmox_create_vm` / `proxmox_proxmox_create_lxc`
- Config: `proxmox_proxmox_get_vm_config` / `proxmox_proxmox_get_lxc_config`
- Start/Stop/Reboot: `proxmox_proxmox_start_vm`, `proxmox_proxmox_shutdown_vm`, `proxmox_proxmox_reboot_vm`
- Migrate: `proxmox_proxmox_migrate_vm` / `proxmox_proxmox_migrate_lxc`
- Snapshot: `proxmox_proxmox_create_snapshot` → `proxmox_proxmox_rollback_snapshot`
- Delete: Stop first, then `proxmox_proxmox_delete_vm`

### Node Operations
- Status: `proxmox_proxmox_node_status`
- Services: `proxmox_proxmox_list_services`, `proxmox_proxmox_restart_service`
- Reboot: `proxmox_proxmox_reboot_node`
- APT: `proxmox_proxmox_list_apt_updates`, `proxmox_proxmox_refresh_apt_updates`
- DNS: `proxmox_proxmox_node_dns`, `proxmox_proxmox_update_dns`

### Ceph
- Status: `proxmox_proxmox_ceph_status`
- Pools: `proxmox_proxmox_list_ceph_pools`
- OSDs: `proxmox_proxmox_list_ceph_osd`

### Firewall
- Cluster rules: `proxmox_proxmox_list_cluster_firewall_rules`
- VM rules: `proxmox_proxmox_list_vm_firewall_rules`

### Important Rules
- ALWAYS confirm with `confirm=true` for mutating operations
- NEVER commit PVE credentials to git
- ALWAYS use read-only tools first before mutations
- For bulk operations, use `proxmox_proxmox_bulk_start_guests` / `proxmox_proxmox_bulk_shutdown_guests`

## Examples

### Create and start a VM
```
1. proxmox_proxmox_get_next_vmid → get next available ID
2. proxmox_proxmox_create_vm(node="pve", vmid=100, name="test-vm", cores=2, memory=4096, disk_size="32G", storage="local-lvm", confirm=true)
3. proxmox_proxmox_start_vm(node="pve", vmid=100, confirm=true)
4. proxmox_proxmox_get_vm_config(node="pve", vmid=100) → verify
```

### Migrate a VM
```
1. proxmox_proxmox_get_vm_config(node="pve", vmid=100) → confirm source
2. proxmox_proxmox_migrate_vm(node="pve", vmid=100, target="pve2", confirm=true)
3. proxmox_proxmox_get_vm_config(node="pve2", vmid=100) → verify on target
```

## Failure Modes

- **Elevated operation without confirm**: All mutating operations require `confirm=true`. If tool returns error, re-invoke with confirm.
- **VM not running**: Start VM before guest agent commands
- **Storage full**: Check `proxmox_proxmox_storage_status` before creating disks
- **Node offline**: Use `proxmox_proxmox_cluster_status` to verify cluster quorum