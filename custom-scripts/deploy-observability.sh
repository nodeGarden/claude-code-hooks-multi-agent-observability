#!/bin/bash

# Deploy Claude Code Multi-Agent Observability System
# Usage: ./deploy-observability.sh <target-project-path> [--dry-run] [--skip-backup]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Get script directory (source of deployment)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SOURCE_ROOT="$(dirname "$SCRIPT_DIR")"
SOURCE_CLAUDE="$SOURCE_ROOT/.claude"

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

echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  Claude Code Multi-Agent Observability Deployment     ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Source: ${GREEN}$SOURCE_CLAUDE${NC}"
echo -e "Target: ${GREEN}$TARGET_PROJECT${NC}"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}━━━ DRY RUN MODE - No files will be modified ━━━${NC}"
    echo ""
fi

# Create backup directory with timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$TARGET_PROJECT/.claude-backups/backup_$TIMESTAMP"

if [ "$SKIP_BACKUP" = false ]; then
    if [ "$DRY_RUN" = false ]; then
        echo -e "${YELLOW}Creating backup...${NC}"
        mkdir -p "$BACKUP_DIR"

        # Backup existing .claude folder if it exists
        if [ -d "$TARGET_CLAUDE" ]; then
            cp -R "$TARGET_CLAUDE" "$BACKUP_DIR/"
            echo -e "${GREEN}✓ Backed up existing .claude folder to:${NC}"
            echo -e "  ${BLUE}$BACKUP_DIR${NC}"
        fi
    else
        echo -e "${YELLOW}[DRY RUN] Would create backup at: $BACKUP_DIR${NC}"
    fi
    echo ""
else
    echo -e "${YELLOW}Skipping backup (--skip-backup flag)${NC}"
    echo ""
fi

# Directories to deploy from source .claude
CLAUDE_DIRS=(
    "hooks"
    "agents"
    "skills"
    "commands"
    "output-styles"
    "status_lines"
    "data"
)

# Files to deploy from source .claude root
CLAUDE_FILES=(
    "settings.json"
)

echo -e "${BLUE}━━━ Deploying .claude Directory Structure ━━━${NC}"
echo ""

# Create .claude directory if it doesn't exist
if [ "$DRY_RUN" = false ]; then
    mkdir -p "$TARGET_CLAUDE"
else
    echo -e "${YELLOW}[DRY RUN] Would create $TARGET_CLAUDE${NC}"
fi

# Deploy directories
for dir in "${CLAUDE_DIRS[@]}"; do
    SOURCE_DIR="$SOURCE_CLAUDE/$dir"
    TARGET_DIR="$TARGET_CLAUDE/$dir"

    if [ ! -d "$SOURCE_DIR" ]; then
        echo -e "${YELLOW}⊘ Skipping $dir (doesn't exist in source)${NC}"
        continue
    fi

    echo -e "${CYAN}→ $dir/${NC}"

    # Check if target exists
    if [ -d "$TARGET_DIR" ]; then
        if [ "$DRY_RUN" = false ]; then
            read -p "  Directory exists. [O]verwrite, [M]erge, or [S]kip? (o/m/s) " -n 1 -r
            echo

            case $REPLY in
                [Oo]* )
                    # Remove existing and copy fresh
                    rm -rf "$TARGET_DIR"
                    cp -R "$SOURCE_DIR" "$TARGET_DIR"
                    echo -e "${GREEN}  ✓ Overwritten${NC}"
                    ;;
                [Mm]* )
                    # Merge: copy files, ask about conflicts
                    echo -e "${YELLOW}  → Merging...${NC}"
                    cp -R "$SOURCE_DIR/"* "$TARGET_DIR/" 2>/dev/null || true
                    echo -e "${GREEN}  ✓ Merged${NC}"
                    ;;
                * )
                    echo -e "${YELLOW}  ⊘ Skipped${NC}"
                    ;;
            esac
        else
            echo -e "${YELLOW}  [DRY RUN] Would prompt for overwrite/merge/skip${NC}"
        fi
    else
        # Target doesn't exist, just copy
        if [ "$DRY_RUN" = false ]; then
            cp -R "$SOURCE_DIR" "$TARGET_DIR"
            echo -e "${GREEN}  ✓ Deployed${NC}"
        else
            echo -e "${YELLOW}  [DRY RUN] Would deploy${NC}"
        fi
    fi
done

echo ""
echo -e "${BLUE}━━━ Deploying .claude Configuration Files ━━━${NC}"
echo ""

# Deploy files
for file in "${CLAUDE_FILES[@]}"; do
    SOURCE_FILE="$SOURCE_CLAUDE/$file"
    TARGET_FILE="$TARGET_CLAUDE/$file"

    if [ ! -f "$SOURCE_FILE" ]; then
        echo -e "${YELLOW}⊘ Skipping $file (doesn't exist in source)${NC}"
        continue
    fi

    echo -e "${CYAN}→ $file${NC}"

    # Check if target exists
    if [ -f "$TARGET_FILE" ]; then
        if [ "$DRY_RUN" = false ]; then
            read -p "  File exists. Overwrite? (y/n) " -n 1 -r
            echo

            if [[ $REPLY =~ ^[Yy]$ ]]; then
                cp "$SOURCE_FILE" "$TARGET_FILE"
                echo -e "${GREEN}  ✓ Overwritten${NC}"
            else
                echo -e "${YELLOW}  ⊘ Skipped (keeping existing)${NC}"
            fi
        else
            echo -e "${YELLOW}  [DRY RUN] Would prompt for overwrite${NC}"
        fi
    else
        # Target doesn't exist, just copy
        if [ "$DRY_RUN" = false ]; then
            cp "$SOURCE_FILE" "$TARGET_FILE"
            echo -e "${GREEN}  ✓ Deployed${NC}"
        else
            echo -e "${YELLOW}  [DRY RUN] Would deploy${NC}"
        fi
    fi
done

# Handle settings.local.json specially
echo ""
echo -e "${CYAN}→ settings.local.json${NC}"
SOURCE_LOCAL="$SOURCE_CLAUDE/settings.local.json"
TARGET_LOCAL="$TARGET_CLAUDE/settings.local.json"

if [ -f "$SOURCE_LOCAL" ]; then
    if [ -f "$TARGET_LOCAL" ]; then
        echo -e "${YELLOW}  ⊘ Skipping (preserve local settings)${NC}"
    else
        if [ "$DRY_RUN" = false ]; then
            read -p "  Copy settings.local.json template? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                cp "$SOURCE_LOCAL" "$TARGET_LOCAL"
                echo -e "${GREEN}  ✓ Deployed${NC}"
                echo -e "${YELLOW}  ⚠ Review and customize settings.local.json for this project${NC}"
            else
                echo -e "${YELLOW}  ⊘ Skipped${NC}"
            fi
        else
            echo -e "${YELLOW}  [DRY RUN] Would prompt to copy${NC}"
        fi
    fi
else
    echo -e "${YELLOW}  ⊘ No settings.local.json in source${NC}"
fi

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║              Deployment Complete!                      ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ "$SKIP_BACKUP" = false ]; then
    echo -e "Backup: ${YELLOW}$BACKUP_DIR${NC}"
    echo ""
fi

echo -e "${GREEN}Deployed Components:${NC}"
echo -e "  • Hooks with plugin system"
echo -e "  • Multi-agent system (subagents)"
echo -e "  • Skills framework"
echo -e "  • Slash commands"
echo -e "  • Output styles"
echo -e "  • Status line configuration"
echo -e "  • Session data structure"
echo ""

echo -e "${YELLOW}Next Steps:${NC}"
echo -e "  1. Review ${CYAN}$TARGET_CLAUDE/settings.json${NC}"
echo -e "  2. Customize ${CYAN}$TARGET_CLAUDE/settings.local.json${NC} (if deployed)"
echo -e "  3. Configure plugins in ${CYAN}$TARGET_CLAUDE/hooks/plugins/${NC}"
echo -e "  4. Test by running Claude Code in ${CYAN}$TARGET_PROJECT${NC}"
echo ""

if [ "$SKIP_BACKUP" = false ]; then
    echo -e "${YELLOW}Rollback:${NC}"
    echo -e "  cd $TARGET_PROJECT"
    echo -e "  mv .claude .claude-failed"
    echo -e "  cp -R .claude-backups/backup_$TIMESTAMP/.claude ."
    echo ""
fi

echo -e "${CYAN}For plugin-only deployment, use:${NC}"
echo -e "  ./custom-scripts/deploy-hooks-v2.sh <target-project>"
echo ""
