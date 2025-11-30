#!/bin/bash

# Deploy Claude Code Hooks Plugin System (Version 2)
# Usage: ./deploy-hooks-v2.sh <target-project-path> [--dry-run] [--skip-backup]

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
SOURCE_HOOKS="$SOURCE_CLAUDE/hooks"

# Parse arguments
TARGET_PROJECT=""
DRY_RUN=false
SKIP_BACKUP=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --skip-backup)
            SKIP_BACKUP=true
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
    echo "Usage: $0 <target-project-path> [--dry-run] [--skip-backup]"
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

if [ "$SKIP_BACKUP" = false ]; then
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
else
    echo -e "${YELLOW}Skipping backup (--skip-backup flag)${NC}"
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
    cp "$SOURCE_HOOKS/plugin_manager.py" "$TARGET_HOOKS/"
    echo -e "${GREEN}  ✓ Deployed${NC}"
else
    echo -e "${YELLOW}  [DRY RUN] Would deploy${NC}"
fi

# Deploy PLUGIN_DEVELOPMENT.md
echo -e "→ PLUGIN_DEVELOPMENT.md"
if [ "$DRY_RUN" = false ]; then
    cp "$SOURCE_HOOKS/PLUGIN_DEVELOPMENT.md" "$TARGET_HOOKS/"
    echo -e "${GREEN}  ✓ Deployed${NC}"
else
    echo -e "${YELLOW}  [DRY RUN] Would deploy${NC}"
fi

# Deploy TEMPLATE plugin
echo -e "→ plugins/TEMPLATE/"
if [ "$DRY_RUN" = false ]; then
    mkdir -p "$TARGET_HOOKS/plugins/TEMPLATE"
    cp -R "$SOURCE_HOOKS/plugins/TEMPLATE/"* "$TARGET_HOOKS/plugins/TEMPLATE/"
    echo -e "${GREEN}  ✓ Deployed${NC}"
else
    echo -e "${YELLOW}  [DRY RUN] Would deploy${NC}"
fi

# Deploy event_notifications plugin (optional)
echo ""
if [ "$DRY_RUN" = false ]; then
    read -p "Deploy event_notifications plugin? (y/n) " -n 1 -r
    echo
else
    echo -e "${YELLOW}[DRY RUN] Would prompt for event_notifications plugin${NC}"
    REPLY="n"
fi

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "→ plugins/event_notifications/"
    if [ "$DRY_RUN" = false ]; then
        mkdir -p "$TARGET_HOOKS/plugins/event_notifications"
        cp -R "$SOURCE_HOOKS/plugins/event_notifications/"* "$TARGET_HOOKS/plugins/event_notifications/"
        echo -e "${GREEN}  ✓ Deployed${NC}"
    else
        echo -e "${YELLOW}  [DRY RUN] Would deploy${NC}"
    fi
fi

echo ""
echo -e "${BLUE}Deploying Hook Files with Plugin Integration...${NC}"
echo ""

# List of hook files to deploy (these already have plugin integration)
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

for hook in "${HOOKS[@]}"; do
    SOURCE_HOOK="$SOURCE_HOOKS/$hook"
    TARGET_HOOK="$TARGET_HOOKS/$hook"

    # Check if source hook has plugin integration
    if grep -q "from plugin_manager import execute_plugins" "$SOURCE_HOOK"; then
        # Check if target hook exists and already has plugin integration
        if [ -f "$TARGET_HOOK" ] && grep -q "from plugin_manager import execute_plugins" "$TARGET_HOOK"; then
            echo -e "${GREEN}✓ $hook already has plugin integration${NC}"
            continue
        fi

        echo -e "→ Deploying $hook with plugin integration"
        if [ "$DRY_RUN" = false ]; then
            # Ask user if they want to overwrite
            if [ -f "$TARGET_HOOK" ]; then
                read -p "  File exists. Overwrite? (y/n) " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    echo -e "${YELLOW}  ⊘ Skipped${NC}"
                    continue
                fi
            fi
            cp "$SOURCE_HOOK" "$TARGET_HOOK"
            echo -e "${GREEN}  ✓ Deployed${NC}"
        else
            echo -e "${YELLOW}  [DRY RUN] Would deploy${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ $hook in source does not have plugin integration${NC}"
    fi
done

# Deploy utils directory if needed
echo ""
echo -e "${BLUE}Checking utils directory...${NC}"
if [ ! -d "$TARGET_HOOKS/utils" ]; then
    echo -e "→ Deploying utils/ directory"
    if [ "$DRY_RUN" = false ]; then
        cp -R "$SOURCE_HOOKS/utils" "$TARGET_HOOKS/"
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

if [ "$SKIP_BACKUP" = false ]; then
    echo -e "Backup location: ${YELLOW}$BACKUP_DIR${NC}"
    echo ""
fi

echo -e "Next steps:"
echo -e "  1. Review deployed files in ${YELLOW}$TARGET_HOOKS${NC}"
echo -e "  2. Configure plugins in ${YELLOW}$TARGET_HOOKS/plugins/${NC}"
echo -e "  3. Test hooks by running Claude Code in the target project"
echo ""

if [ "$SKIP_BACKUP" = false ]; then
    echo -e "To rollback:"
    echo -e "  ${YELLOW}rm -rf $TARGET_CLAUDE && cp -R $BACKUP_DIR/.claude $TARGET_CLAUDE${NC}"
    echo ""
fi
