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
MAGENTA='\033[0;35m'
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

# Arrays to track conflicts
declare -a CONFLICT_DIRS=()
declare -a CONFLICT_FILES=()
declare -a MERGED_DIRS=()
declare -a DEPLOYED_DIRS=()
declare -a DEPLOYED_FILES=()
declare -a SKIPPED_ITEMS=()

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
            echo -e "${GREEN}✓ Backed up existing .claude folder${NC}"
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

echo -e "${BLUE}━━━ Scanning for conflicts (defaulting to merge) ━━━${NC}"
echo ""

# Create .claude directory if it doesn't exist
if [ "$DRY_RUN" = false ]; then
    mkdir -p "$TARGET_CLAUDE"
fi

# Scan directories for conflicts
for dir in "${CLAUDE_DIRS[@]}"; do
    SOURCE_DIR="$SOURCE_CLAUDE/$dir"
    TARGET_DIR="$TARGET_CLAUDE/$dir"

    if [ ! -d "$SOURCE_DIR" ]; then
        SKIPPED_ITEMS+=("$dir/ (not in source)")
        continue
    fi

    if [ -d "$TARGET_DIR" ]; then
        CONFLICT_DIRS+=("$dir/")
        echo -e "${YELLOW}⊕ $dir/ ${NC}(exists, will merge)"
    else
        echo -e "${GREEN}→ $dir/ ${NC}(new, will deploy)"
    fi
done

# Scan files for conflicts
for file in "${CLAUDE_FILES[@]}"; do
    SOURCE_FILE="$SOURCE_CLAUDE/$file"
    TARGET_FILE="$TARGET_CLAUDE/$file"

    if [ ! -f "$SOURCE_FILE" ]; then
        SKIPPED_ITEMS+=("$file (not in source)")
        continue
    fi

    if [ -f "$TARGET_FILE" ]; then
        CONFLICT_FILES+=("$file")
        echo -e "${YELLOW}⊕ $file ${NC}(exists, will overwrite)"
    else
        echo -e "${GREEN}→ $file ${NC}(new, will deploy)"
    fi
done

# Handle settings.local.json
SOURCE_LOCAL="$SOURCE_CLAUDE/settings.local.json"
TARGET_LOCAL="$TARGET_CLAUDE/settings.local.json"

if [ -f "$SOURCE_LOCAL" ]; then
    if [ -f "$TARGET_LOCAL" ]; then
        echo -e "${CYAN}⊘ settings.local.json ${NC}(exists, will preserve)"
        SKIPPED_ITEMS+=("settings.local.json (preserved)")
    else
        echo -e "${GREEN}→ settings.local.json ${NC}(new, will deploy)"
    fi
fi

# Show conflict summary if there are any
TOTAL_CONFLICTS=$((${#CONFLICT_DIRS[@]} + ${#CONFLICT_FILES[@]}))

if [ $TOTAL_CONFLICTS -gt 0 ]; then
    echo ""
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${MAGENTA}              CONFLICT SUMMARY${NC}"
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}The following items exist in the target and will be updated:${NC}"
    echo ""

    # Print table header
    printf "${CYAN}%-30s %-20s %-30s${NC}\n" "ITEM" "ACTION" "DESCRIPTION"
    printf "${CYAN}%-30s %-20s %-30s${NC}\n" "----" "------" "-----------"

    # Print directories
    for dir in "${CONFLICT_DIRS[@]}"; do
        printf "%-30s ${YELLOW}%-20s${NC} %-30s\n" "$dir" "MERGE" "Files will be merged"
    done

    # Print files
    for file in "${CONFLICT_FILES[@]}"; do
        printf "%-30s ${YELLOW}%-20s${NC} %-30s\n" "$file" "OVERWRITE" "File will be replaced"
    done

    echo ""
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    if [ "$DRY_RUN" = false ]; then
        echo -e "${YELLOW}How would you like to proceed?${NC}"
        echo -e "  ${GREEN}[A]${NC} Accept all (merge directories, overwrite files)"
        echo -e "  ${RED}[D]${NC} Decline all (skip everything with conflicts)"
        echo -e "  ${CYAN}[I]${NC} Individual review (prompt for each item)"
        echo ""
        read -p "Choice [A/d/i]: " -n 1 -r APPROVAL_CHOICE
        echo ""
        echo ""

        # Default to Accept if just Enter pressed
        if [ -z "$APPROVAL_CHOICE" ]; then
            APPROVAL_CHOICE="A"
        fi

        case $APPROVAL_CHOICE in
            [Aa]* )
                echo -e "${GREEN}✓ Accepting all conflicts${NC}"
                INDIVIDUAL_REVIEW=false
                SKIP_ALL=false
                ;;
            [Dd]* )
                echo -e "${RED}✗ Declining all conflicts${NC}"
                INDIVIDUAL_REVIEW=false
                SKIP_ALL=true
                ;;
            [Ii]* )
                echo -e "${CYAN}→ Individual review mode${NC}"
                INDIVIDUAL_REVIEW=true
                SKIP_ALL=false
                ;;
            * )
                echo -e "${GREEN}✓ Accepting all conflicts (default)${NC}"
                INDIVIDUAL_REVIEW=false
                SKIP_ALL=false
                ;;
        esac
        echo ""
    else
        echo -e "${YELLOW}[DRY RUN] Would prompt for approval${NC}"
        INDIVIDUAL_REVIEW=false
        SKIP_ALL=false
    fi
fi

echo -e "${BLUE}━━━ Deploying .claude Directory Structure ━━━${NC}"
echo ""

# Deploy directories
for dir in "${CLAUDE_DIRS[@]}"; do
    SOURCE_DIR="$SOURCE_CLAUDE/$dir"
    TARGET_DIR="$TARGET_CLAUDE/$dir"

    if [ ! -d "$SOURCE_DIR" ]; then
        continue
    fi

    # Check if target exists
    if [ -d "$TARGET_DIR" ]; then
        # Directory exists - merge or skip based on approval
        DO_MERGE=true

        if [ "$SKIP_ALL" = true ]; then
            DO_MERGE=false
        elif [ "$INDIVIDUAL_REVIEW" = true ] && [ "$DRY_RUN" = false ]; then
            read -p "Merge $dir/? (Y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Nn]$ ]]; then
                DO_MERGE=false
            fi
        fi

        if [ "$DO_MERGE" = true ]; then
            if [ "$DRY_RUN" = false ]; then
                cp -R "$SOURCE_DIR/"* "$TARGET_DIR/" 2>/dev/null || true
                MERGED_DIRS+=("$dir/")
                echo -e "${GREEN}✓ Merged $dir/${NC}"
            else
                echo -e "${YELLOW}[DRY RUN] Would merge $dir/${NC}"
            fi
        else
            SKIPPED_ITEMS+=("$dir/ (user declined)")
            echo -e "${YELLOW}⊘ Skipped $dir/${NC}"
        fi
    else
        # Target doesn't exist, just copy
        if [ "$DRY_RUN" = false ]; then
            cp -R "$SOURCE_DIR" "$TARGET_DIR"
            DEPLOYED_DIRS+=("$dir/")
            echo -e "${GREEN}✓ Deployed $dir/${NC}"
        else
            echo -e "${YELLOW}[DRY RUN] Would deploy $dir/${NC}"
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
        continue
    fi

    # Check if target exists
    if [ -f "$TARGET_FILE" ]; then
        # File exists - overwrite or skip based on approval
        DO_OVERWRITE=true

        if [ "$SKIP_ALL" = true ]; then
            DO_OVERWRITE=false
        elif [ "$INDIVIDUAL_REVIEW" = true ] && [ "$DRY_RUN" = false ]; then
            read -p "Overwrite $file? (Y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Nn]$ ]]; then
                DO_OVERWRITE=false
            fi
        fi

        if [ "$DO_OVERWRITE" = true ]; then
            if [ "$DRY_RUN" = false ]; then
                cp "$SOURCE_FILE" "$TARGET_FILE"
                DEPLOYED_FILES+=("$file")
                echo -e "${GREEN}✓ Overwritten $file${NC}"
            else
                echo -e "${YELLOW}[DRY RUN] Would overwrite $file${NC}"
            fi
        else
            SKIPPED_ITEMS+=("$file (user declined)")
            echo -e "${YELLOW}⊘ Skipped $file${NC}"
        fi
    else
        # Target doesn't exist, just copy
        if [ "$DRY_RUN" = false ]; then
            cp "$SOURCE_FILE" "$TARGET_FILE"
            DEPLOYED_FILES+=("$file")
            echo -e "${GREEN}✓ Deployed $file${NC}"
        else
            echo -e "${YELLOW}[DRY RUN] Would deploy $file${NC}"
        fi
    fi
done

# Handle settings.local.json specially
echo ""
if [ -f "$SOURCE_LOCAL" ]; then
    if [ -f "$TARGET_LOCAL" ]; then
        echo -e "${CYAN}⊘ Preserved settings.local.json (keeping target's version)${NC}"
    else
        if [ "$DRY_RUN" = false ]; then
            read -p "Copy settings.local.json template? (y/N) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                cp "$SOURCE_LOCAL" "$TARGET_LOCAL"
                DEPLOYED_FILES+=("settings.local.json")
                echo -e "${GREEN}✓ Deployed settings.local.json${NC}"
                echo -e "${YELLOW}⚠ Review and customize for this project${NC}"
            else
                SKIPPED_ITEMS+=("settings.local.json (user declined)")
                echo -e "${YELLOW}⊘ Skipped settings.local.json${NC}"
            fi
        else
            echo -e "${YELLOW}[DRY RUN] Would prompt to copy settings.local.json${NC}"
        fi
    fi
fi

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║              Deployment Complete!                      ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Show deployment summary
if [ ${#DEPLOYED_DIRS[@]} -gt 0 ] || [ ${#MERGED_DIRS[@]} -gt 0 ] || [ ${#DEPLOYED_FILES[@]} -gt 0 ]; then
    echo -e "${GREEN}✓ Deployment Summary:${NC}"

    if [ ${#DEPLOYED_DIRS[@]} -gt 0 ]; then
        echo -e "  ${GREEN}New directories:${NC} ${DEPLOYED_DIRS[*]}"
    fi

    if [ ${#MERGED_DIRS[@]} -gt 0 ]; then
        echo -e "  ${YELLOW}Merged directories:${NC} ${MERGED_DIRS[*]}"
    fi

    if [ ${#DEPLOYED_FILES[@]} -gt 0 ]; then
        echo -e "  ${GREEN}Files deployed:${NC} ${DEPLOYED_FILES[*]}"
    fi

    echo ""
fi

if [ ${#SKIPPED_ITEMS[@]} -gt 0 ]; then
    echo -e "${YELLOW}⊘ Skipped Items:${NC}"
    for item in "${SKIPPED_ITEMS[@]}"; do
        echo -e "  ${YELLOW}•${NC} $item"
    done
    echo ""
fi

if [ "$SKIP_BACKUP" = false ]; then
    echo -e "Backup: ${YELLOW}$BACKUP_DIR${NC}"
    echo ""
fi

echo -e "${CYAN}Deployed Components:${NC}"
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
