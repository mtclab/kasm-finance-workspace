---
name: zabbix-monitoring
description: Set up and manage Zabbix monitoring for HomePilot infrastructure. Trigger on zabbix, monitoring, alerts, triggers, host, template, item, dashboard, metric, SNMP, agent, LLD, discovery. Covers host registration, template linking, trigger creation, action configuration, dashboard setup.
---

# Zabbix Monitoring Setup

Configure and manage Zabbix monitoring for HomePilot infrastructure (dev server, PVE, LXCs).

## When to Use

- User mentions Zabbix, monitoring, alerting, dashboards, metrics
- Setting up host monitoring (LXC 103, 104, dev server)
- Creating templates, items, triggers, actions
- Configuring SNMP, Zabbix agent, or ICMP checks
- Reviewing problems/events in Zabbix
- Creating maintenance windows for planned downtime

## Infrastructure

| Host | IP | Role |
|------|-----|------|
| Zabbix Server | 10.96.16.51 | LXC 104 (homepilot-agent) |
| PVE Node | 10.96.16.19 | Proxmox hypervisor |
| Dev Server | 10.96.16.18 | HomePilot v2 backend |
| ProxMox MCP | 10.96.16.50 | LXC 103 (SSE server) |

## Steps

### 1. Create Host Groups
```python
zabbix_hostgroup_create(name="HomePilot Infrastructure")
zabbix_hostgroup_create(name="Proxmox Nodes")
zabbix_hostgroup_create(name="Linux Servers")
```

### 2. Register Hosts
```python
# Dev server
zabbix_host_create(
    host="homepilot-dev",
    name="HomePilot Dev Server",
    groups=[{"groupid": "<homepilot_infra_groupid>"}],
    interfaces=[{
        "type": 1,  # Zabbix agent
        "main": 1,
        "useip": 1,
        "ip": "10.96.16.18",
        "dns": "",
        "port": "10050"
    }]
)

# PVE node
zabbix_host_create(
    host="pve-node",
    name="PVE Node (10.96.16.19)",
    groups=[{"groupid": "<proxmox_nodes_groupid>"}],
    interfaces=[{
        "type": 1, "main": 1, "useip": 1,
        "ip": "10.96.16.19", "port": "10050"
    }]
)
```

### 3. Link Templates
```python
# Find Linux template
zabbix_template_get(search={"name": "Linux"}, output="extend")

# Link to hosts
# Use host update to add templates
```

### 4. Create Items
```python
# HomePilot health check
zabbix_item_create(
    name="HomePilot Health",
    key_="http.get[http://10.96.16.18:8000/health]",
    hostid="<homepilot_hostid>",
    type_=0,  # Zabbix agent
    value_type=3,  # unsigned int
    delay="1m"
)

# PVE API health
zabbix_item_create(
    name="PVE API Status",
    key_="http.get[https://10.96.16.19:8006/api2json/nodes/pve/status]",
    hostid="<pve_hostid>",
    type_=0,
    value_type=3,
    delay="2m"
)
```

### 5. Create Triggers
```python
# HomePilot down
zabbix_trigger_create(
    description="HomePilot is down",
    expression="last(/homepilot-dev/HomePilot Health)=0",
    priority=4  # High
)

# PVE API unreachable
zabbix_trigger_create(
    description="PVE API unreachable",
    expression="last(/pve-node/PVE API Status)=0",
    priority=5  # Disaster
)
```

### 6. Create Actions (Alerts)
```python
zabbix_action_get(search={"name": "HomePilot"}, output="extend")
# Create action to send notifications on trigger
```

### 7. Review Problems
```python
# Current problems
zabbix_problem_get(output="extend", recent=False, sortfield="eventid", sortorder="DESC")

# Unacknowledged only
zabbix_problem_get(acknowledged=False, sortfield="eventid", sortorder="DESC", limit=10)
```

## Maintenance Windows

```python
# Planned maintenance for deployment
zabbix_maintenance_create(
    name="HomePilot v2.2.2 deployment",
    active_since=<unix_timestamp_start>,
    active_till=<unix_timestamp_end>,
    hostids=["<homepilot_hostid>"]
)
```

## Failure Modes

- **Zabbix agent not running**: Install with `apt install zabbix-agent`, configure `ServerActive` and `Hostname`
- **Host unreachable**: Check firewall allows port 10050, verify IP
- **Template not found**: Use `zabbix_template_get(search={"name": "Linux"})` to find correct template ID
- **Trigger expression invalid**: Use Zabbix expression builder, test with `last(/host/item)=0`