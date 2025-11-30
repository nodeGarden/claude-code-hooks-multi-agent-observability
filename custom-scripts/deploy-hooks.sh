#!/bin/bash

# Deploy Claude Code Hooks Plugin System
# Usage: ./deploy-hooks.sh <target-project-path> [--dry-run]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory (source of deployment)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SOURCE_ROOT="$(dirname "$SCRIPT_DIR")"
SOURCE_CLAUDE="$SOURCE_ROOT/.claude"

# Parse arguments
TARGET_PROJECT=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            TARGET_PROJECT="$1"
            shift
            ;;
    esac
done

# Validate target project path
if [ -z "$TARGET_PROJECT" ]; then
    echo -e "${RED}Error: Target project path is required${NC}"
    echo "Usage: $0 <target-project-path> [--dry-run]"
    exit 1
fi

# Convert to absolute path
TARGET_PROJECT="$(cd "$TARGET_PROJECT" 2>/dev/null && pwd)" || {
    echo -e "${RED}Error: Target project path does not exist: $TARGET_PROJECT${NC}"
    exit 1
}

TARGET_CLAUDE="$TARGET_PROJECT/.claude"
TARGET_HOOKS="$TARGET_CLAUDE/hooks"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Claude Code Hooks Plugin System Deployment${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "Source: ${GREEN}$SOURCE_CLAUDE${NC}"
echo -e "Target: ${GREEN}$TARGET_PROJECT${NC}"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}DRY RUN MODE - No files will be modified${NC}"
    echo ""
fi

# Create backup directory with timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$TARGET_PROJECT/.claude-backups/backup_$TIMESTAMP"

if [ "$DRY_RUN" = false ]; then
    echo -e "${YELLOW}Creating backup at: $BACKUP_DIR${NC}"
    mkdir -p "$BACKUP_DIR"

    # Backup existing .claude folder if it exists
    if [ -d "$TARGET_CLAUDE" ]; then
        cp -R "$TARGET_CLAUDE" "$BACKUP_DIR/"
        echo -e "${GREEN}✓ Backed up existing .claude folder${NC}"
    fi
else
    echo -e "${YELLOW}[DRY RUN] Would create backup at: $BACKUP_DIR${NC}"
fi

# Create .claude/hooks directory if it doesn't exist
if [ "$DRY_RUN" = false ]; then
    mkdir -p "$TARGET_HOOKS"
    echo -e "${GREEN}✓ Ensured .claude/hooks directory exists${NC}"
else
    echo -e "${YELLOW}[DRY RUN] Would create $TARGET_HOOKS${NC}"
fi

echo ""
echo -e "${BLUE}Deploying Plugin System Files...${NC}"
echo ""

# Deploy plugin_manager.py
echo -e "→ plugin_manager.py"
if [ "$DRY_RUN" = false ]; then
    cp "$SOURCE_CLAUDE/hooks/plugin_manager.py" "$TARGET_HOOKS/"
    echo -e "${GREEN}  ✓ Deployed${NC}"
else
    echo -e "${YELLOW}  [DRY RUN] Would deploy${NC}"
fi

# Deploy PLUGIN_DEVELOPMENT.md
echo -e "→ PLUGIN_DEVELOPMENT.md"
if [ "$DRY_RUN" = false ]; then
    cp "$SOURCE_CLAUDE/hooks/PLUGIN_DEVELOPMENT.md" "$TARGET_HOOKS/"
    echo -e "${GREEN}  ✓ Deployed${NC}"
else
    echo -e "${YELLOW}  [DRY RUN] Would deploy${NC}"
fi

# Deploy TEMPLATE plugin
echo -e "→ plugins/TEMPLATE/"
if [ "$DRY_RUN" = false ]; then
    mkdir -p "$TARGET_HOOKS/plugins/TEMPLATE"
    cp -R "$SOURCE_CLAUDE/hooks/plugins/TEMPLATE/"* "$TARGET_HOOKS/plugins/TEMPLATE/"
    echo -e "${GREEN}  ✓ Deployed${NC}"
else
    echo -e "${YELLOW}  [DRY RUN] Would deploy${NC}"
fi

# Deploy event_notifications plugin (optional)
echo ""
read -p "Deploy event_notifications plugin? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "→ plugins/event_notifications/"
    if [ "$DRY_RUN" = false ]; then
        mkdir -p "$TARGET_HOOKS/plugins/event_notifications"
        cp -R "$SOURCE_CLAUDE/hooks/plugins/event_notifications/"* "$TARGET_HOOKS/plugins/event_notifications/"
        echo -e "${GREEN}  ✓ Deployed${NC}"
    else
        echo -e "${YELLOW}  [DRY RUN] Would deploy${NC}"
    fi
fi

echo ""
echo -e "${BLUE}Updating Hook Files...${NC}"
echo ""

# List of hook files to update
HOOKS=(
    "notification.py"
    "post_tool_use.py"
    "pre_compact.py"
    "pre_tool_use.py"
    "session_end.py"
    "session_start.py"
    "stop.py"
    "subagent_stop.py"
    "user_prompt_submit.py"
)

# Plugin integration code to add
PLUGIN_CODE='
        # Execute plugins
        try:
            from plugin_manager import execute_plugins
            execute_plugins("HOOK_NAME", input_data)
        except ImportError:
            pass
'

for hook in "${HOOKS[@]}"; do
    SOURCE_HOOK="$SOURCE_CLAUDE/hooks/$hook"
    TARGET_HOOK="$TARGET_HOOKS/$hook"

    # Check if target hook exists
    if [ ! -f "$TARGET_HOOK" ]; then
        echo -e "${YELLOW}⚠ $hook does not exist in target, copying from source${NC}"
        if [ "$DRY_RUN" = false ]; then
            cp "$SOURCE_HOOK" "$TARGET_HOOK"
            echo -e "${GREEN}  ✓ Copied${NC}"
        else
            echo -e "${YELLOW}  [DRY RUN] Would copy${NC}"
        fi
        continue
    fi

    # Check if already has plugin integration
    if grep -q "from plugin_manager import execute_plugins" "$TARGET_HOOK"; then
        echo -e "${GREEN}✓ $hook already has plugin integration${NC}"
        continue
    fi

    echo -e "→ Adding plugin integration to $hook"

    if [ "$DRY_RUN" = false ]; then
        # Create a temporary file with the updated content
        # We'll add the plugin code before the final sys.exit(0)

        # Extract hook name (e.g., "Stop" from "stop.py")
        hook_name=$(echo "$hook" | sed 's/.py$//' | sed 's/_\(.\)/\U\1/g' | sed 's/^./\U&/')

        # Use Python to properly insert the plugin code
        python3 << EOF
import re

with open("$TARGET_HOOK", 'r') as f:
    content = f.read()

# Find the last sys.exit(0) in the main() function
# Insert plugin code before it
hook_name = "$hook_name"
plugin_code = """
        # Execute plugins
        try:
            from plugin_manager import execute_plugins
            execute_plugins("$hook_name", input_data)
        except ImportError:
            pass

"""

# Find the position to insert (before the last sys.exit(0) in main)
# Look for the pattern of sys.exit(0) that's at the end of the try block in main
pattern = r'(\s+)(# Execute plugins.*?pass\s+)?(sys\.exit\(0\)\s+)(except json\.JSONDecodeError:)'

if re.search(r'from plugin_manager import execute_plugins', content):
    # Already has plugin integration
    print("Already integrated")
else:
    # Try to find a good insertion point
    # Look for the last occurrence of sys.exit(0) before exception handlers
    matches = list(re.finditer(r'(\s+)(sys\.exit\(0\))', content))

    if matches:
        # Find the one that's followed by exception handling
        for match in reversed(matches):
            pos = match.end()
            remaining = content[pos:pos+200]
            if 'except' in remaining:
                # This is likely the right spot
                insert_pos = match.start()
                indent = match.group(1)
                content = content[:insert_pos] + plugin_code + indent + content[insert_pos:]
                break

    with open("$TARGET_HOOK", 'w') as f:
        f.write(content)
EOF

        echo -e "${GREEN}  ✓ Updated${NC}"
    else
        echo -e "${YELLOW}  [DRY RUN] Would update${NC}"
    fi
done

# Deploy utils directory if it doesn't exist
echo ""
echo -e "${BLUE}Checking utils directory...${NC}"
if [ ! -d "$TARGET_HOOKS/utils" ]; then
    echo -e "→ Deploying utils/ directory"
    if [ "$DRY_RUN" = false ]; then
        cp -R "$SOURCE_CLAUDE/hooks/utils" "$TARGET_HOOKS/"
        echo -e "${GREEN}  ✓ Deployed${NC}"
    else
        echo -e "${YELLOW}  [DRY RUN] Would deploy${NC}"
    fi
else
    echo -e "${GREEN}✓ utils/ directory already exists${NC}"
fi

echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "Backup location: ${YELLOW}$BACKUP_DIR${NC}"
echo ""
echo -e "Next steps:"
echo -e "  1. Review deployed files in ${YELLOW}$TARGET_CLAUDE${NC}"
echo -e "  2. Configure plugins in ${YELLOW}$TARGET_HOOKS/plugins/${NC}"
echo -e "  3. Test hooks by running Claude Code in the target project"
echo ""
echo -e "To rollback:"
echo -e "  ${YELLOW}rm -rf $TARGET_CLAUDE && cp -R $BACKUP_DIR/.claude $TARGET_CLAUDE${NC}"
echo ""
