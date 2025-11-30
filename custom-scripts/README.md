# Custom Scripts

Deployment and management scripts for the Claude Code Hooks Plugin System.

## deploy-hooks-v2.sh ⭐ (Recommended)

Deploy the plugin system by copying complete, verified hook files from source.

### Usage

```bash
./custom-scripts/deploy-hooks-v2.sh <target-project-path> [--dry-run] [--skip-backup]
```

### Why v2?

**Advantages over v1:**
- ✅ More reliable - copies known-good hook files instead of programmatic insertion
- ✅ Interactive - asks before overwriting each existing file
- ✅ Safer - preserves target project's existing hook customizations if user declines
- ✅ Simpler - fewer edge cases and potential bugs

### Examples

```bash
# Deploy to project_manager (interactive)
./custom-scripts/deploy-hooks-v2.sh /Users/mondo/Desktop/Projects/project_manager

# Dry run to preview changes
./custom-scripts/deploy-hooks-v2.sh /path/to/project --dry-run

# Deploy without creating backup (faster, use with caution)
./custom-scripts/deploy-hooks-v2.sh /path/to/project --skip-backup
```

---

## deploy-hooks.sh (Legacy)

Original version that attempts programmatic plugin code insertion.

### Usage

```bash
./custom-scripts/deploy-hooks.sh <target-project-path> [--dry-run]
```

**Note:** This version has known issues with plugin code placement. Use v2 instead.

### What it does

1. **Creates automatic backup** of target project's `.claude` folder
2. **Deploys plugin infrastructure**:
   - `plugin_manager.py` - Plugin discovery and execution system
   - `PLUGIN_DEVELOPMENT.md` - Documentation for plugin developers
   - `plugins/TEMPLATE/` - Template for creating new plugins
3. **Optionally deploys plugins**:
   - `plugins/event_notifications/` - Audio and OS notification plugin
4. **Updates hook files** to integrate with plugin system
5. **Preserves existing configurations** - Only adds plugin integration code

### Examples

**Dry run** (preview changes without modifying files):
```bash
./custom-scripts/deploy-hooks.sh /path/to/target-project --dry-run
```

**Deploy to project_manager**:
```bash
./custom-scripts/deploy-hooks.sh /Users/mondo/Desktop/Projects/project_manager
```

### What files are modified

The script will:
- ✅ Add plugin integration code to hook files (if not already present)
- ✅ Copy plugin system files
- ✅ Create backup before any changes
- ❌ Never overwrite existing hook configurations
- ❌ Never delete existing files

### Hook files updated

The following hook files get plugin integration added:
- `notification.py`
- `post_tool_use.py`
- `pre_compact.py`
- `pre_tool_use.py`
- `session_end.py`
- `session_start.py`
- `stop.py`
- `subagent_stop.py`
- `user_prompt_submit.py`

### Rollback

If you need to rollback, the script shows the backup location:
```bash
rm -rf /path/to/project/.claude
cp -R /path/to/project/.claude-backups/backup_TIMESTAMP/.claude /path/to/project/
```

### Safety features

- Creates timestamped backups in `.claude-backups/`
- Checks if plugin integration already exists (won't duplicate)
- Dry-run mode for previewing changes
- Preserves all existing project-specific files
- Fails safely if target doesn't exist

## Future Scripts

Additional scripts planned:
- `update-hooks.sh` - Update hook files from source
- `sync-plugin.sh` - Sync specific plugin to target project
- `remove-hooks.sh` - Clean removal of plugin system
