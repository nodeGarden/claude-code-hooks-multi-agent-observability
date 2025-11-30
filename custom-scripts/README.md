# Custom Scripts

Deployment and management scripts for the Claude Code Multi-Agent Observability System.

## Quick Start

Choose the right script for your needs:

| Script | Use Case | What It Deploys |
|--------|----------|-----------------|
| `deploy-observability.sh` ⭐ | Full system deployment | Complete `.claude` folder (hooks, agents, skills, etc.) |
| `deploy-hooks-v2.sh` | Plugin system only | Just the hooks plugin infrastructure |
| `deploy-hooks.sh` | Legacy | Programmatic plugin insertion (deprecated) |

---

## deploy-observability.sh ⭐ (Full System)

Deploy the **complete multi-agent observability system** to another Claude Code project.

### What Gets Deployed

**Complete `.claude` directory structure:**
- ✅ `hooks/` - All hooks with plugin system
- ✅ `agents/` - Subagent definitions
- ✅ `skills/` - Skill definitions
- ✅ `commands/` - Slash commands
- ✅ `output-styles/` - Output formatting styles
- ✅ `status_lines/` - Status line configuration
- ✅ `data/` - Session data structure
- ✅ `settings.json` - Project configuration (with prompt)

### Usage

```bash
./custom-scripts/deploy-observability.sh <target-project-path> [--dry-run] [--skip-backup]
```

### Interactive Prompts

For each existing directory/file, you'll be asked:
- **Directories**: `[O]verwrite`, `[M]erge`, or `[S]kip`
- **Files**: `Overwrite? (y/n)`
- **settings.local.json**: Prompts to preserve local settings

### Examples

```bash
# Deploy complete system to project_manager
./custom-scripts/deploy-observability.sh /Users/mondo/Desktop/Projects/project_manager

# Preview what would be deployed
./custom-scripts/deploy-observability.sh /path/to/project --dry-run

# Quick re-deployment without backup
./custom-scripts/deploy-observability.sh /path/to/project --skip-backup
```

### Safety Features

- ✅ Automatic timestamped backups before changes
- ✅ Interactive prompts for conflicts
- ✅ Preserves local settings by default
- ✅ Dry-run mode for safe testing
- ✅ Clear rollback instructions

---

## deploy-hooks-v2.sh (Plugin System Only)

Deploy **just the hooks plugin infrastructure** without touching other `.claude` components.

### What Gets Deployed

**Plugin system only:**
- ✅ `hooks/plugin_manager.py` - Plugin discovery and execution
- ✅ `hooks/PLUGIN_DEVELOPMENT.md` - Developer documentation
- ✅ `hooks/plugins/TEMPLATE/` - Plugin template
- ✅ `hooks/plugins/event_notifications/` - (Optional) Notification plugin
- ✅ Hook files with plugin integration

**Does NOT deploy:**
- ❌ Agents, skills, commands, output-styles
- ❌ settings.json or other project config
- ❌ Existing project-specific hooks

### Usage

```bash
./custom-scripts/deploy-hooks-v2.sh <target-project-path> [--dry-run] [--skip-backup]
```

### Examples

```bash
# Deploy plugin system only
./custom-scripts/deploy-hooks-v2.sh /Users/mondo/Desktop/Projects/project_manager

# Dry run to preview changes
./custom-scripts/deploy-hooks-v2.sh /path/to/project --dry-run

# Deploy without creating backup (faster, use with caution)
./custom-scripts/deploy-hooks-v2.sh /path/to/project --skip-backup
```

### When to Use

Use this when:
- ✅ Target project already has custom agents/skills/commands
- ✅ You only want the plugin infrastructure
- ✅ You want minimal changes to existing setup
- ✅ You're adding plugins to an existing hooks system

---

## deploy-hooks.sh (Legacy)

**⚠️ Deprecated:** Original version that attempts programmatic plugin code insertion.

### Issues

- ❌ Known bugs with plugin code placement
- ❌ Can insert code in wrong locations
- ❌ Less reliable than file copying approach

### Recommendation

Use `deploy-hooks-v2.sh` instead for plugin-only deployments, or `deploy-observability.sh` for full system deployment.

---

## Common Options

All scripts support these flags:

### `--dry-run`
Preview changes without modifying any files. Perfect for:
- Testing before actual deployment
- Seeing what would be overwritten
- Understanding deployment scope

### `--skip-backup`
Skip automatic backup creation. Use when:
- Re-deploying to same project
- You've manually created a backup
- You're confident in rollback ability

**⚠️ Warning:** Without backup, rollback requires manual git operations

---

## Rollback Instructions

If deployment didn't go as planned:

### From Automatic Backup

```bash
cd /path/to/target-project
mv .claude .claude-failed
cp -R .claude-backups/backup_TIMESTAMP/.claude .
```

The exact command is shown at the end of each deployment.

### From Git

If target project is under version control:

```bash
cd /path/to/target-project
git checkout .claude/
# or
git reset --hard HEAD  # if you want to discard all changes
```

---

## File Structure

```
custom-scripts/
├── README.md                    # This file
├── deploy-observability.sh      # Full system deployment ⭐
├── deploy-hooks-v2.sh          # Plugin system only
└── deploy-hooks.sh             # Legacy (deprecated)
```

---

## When to Use Each Script

### Use `deploy-observability.sh` when:
- Setting up a new project with full observability
- Syncing entire `.claude` folder from this repo
- Want all: hooks, agents, skills, commands, styles
- Building a project that needs comprehensive monitoring

### Use `deploy-hooks-v2.sh` when:
- Only need plugin infrastructure
- Project already has custom agents/skills
- Want minimal changes to existing setup
- Just adding event notifications

### Don't use `deploy-hooks.sh`
- Use v2 instead - it's more reliable
- Kept for reference only

---

## Future Enhancements

Scripts planned for future development:

- `update-hooks.sh` - Update just hook files from source
- `sync-plugin.sh` - Sync specific plugin to target project
- `remove-observability.sh` - Clean removal of entire system
- `remove-hooks.sh` - Clean removal of just plugin system
- `validate-deployment.sh` - Test deployed system integrity
