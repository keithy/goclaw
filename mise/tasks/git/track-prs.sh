#!/bin/bash
#MISE description="Track and manage upstream PRs"
# Usage: track-prs.sh [action] [args]
#MISE raw=true

set -e

cd "$MISE_PROJECT_ROOT"

WORKSPACE="${GOCLAW_WORKSPACE:-$HOME/.goclaw/workspace}"
BACKLOG_FILE="$WORKSPACE/PR_BACKLOG.md"
REPO_OWNER="${REPO_OWNER:-nextlevelbuilder}"
REPO_NAME="${REPO_NAME:-goclaw}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Ensure backlog file exists
init_backlog() {
    if [[ ! -f "$BACKLOG_FILE" ]]; then
        mkdir -p "$(dirname "$BACKLOG_FILE")"
        cat > "$BACKLOG_FILE" << 'EOF'
# PR Backlog

| PR | Title | Status | Priority | Notes |
|----|-------|--------|----------|-------|
EOF
        log_info "Created PR_BACKLOG.md at $BACKLOG_FILE"
    fi
}

# Extract PR number from URL or number
extract_pr_number() {
    local input="$1"
    echo "$input" | grep -oE '#?[0-9]+' | tr -d '#'
}

# List all tracked PRs
cmd_list() {
    init_backlog
    
    if [[ ! -s "$BACKLOG_FILE" ]] || [[ $(wc -l < "$BACKLOG_FILE") -le 3 ]]; then
        log_warn "No PRs currently tracked"
        return
    fi
    
    echo ""
    log_info "Tracked PRs:"
    echo ""
    # Print table without header for cleaner display
    tail -n +4 "$BACKLOG_FILE" | while IFS='|' read -r pr title status priority notes _; do
        pr=$(echo "$pr" | tr -d ' ')
        [[ -z "$pr" ]] && continue
        echo "  #$pr | $status | $priority | $title"
    done
    echo ""
}

# Add a PR to tracking
cmd_add() {
    local pr_url="$1"
    [[ -z "$pr_url" ]] && { log_error "Usage: track-prs.sh add <pr_url>"; exit 1; }
    
    # Extract owner/repo/pr from URL if needed
    if [[ "$pr_url" =~ github\.com/([^/]+)/([^/]+)/pull/([0-9]+) ]]; then
        local owner="${BASH_REMATCH[1]}"
        local repo="${BASH_REMATCH[2]}"
        local pr_num="${BASH_REMATCH[3]}"
    else
        local pr_num
        pr_num=$(extract_pr_number "$pr_url")
        [[ -z "$pr_num" ]] && { log_error "Invalid PR reference: $pr_url"; exit 1; }
        local owner="$REPO_OWNER"
        local repo="$REPO_NAME"
    fi
    
    init_backlog
    
    # Fetch PR title from GitHub
    local title
    title=$(gh pr view "$pr_num" --repo "$owner/$repo" --json title -q '.title' 2>/dev/null) || {
        log_error "Failed to fetch PR #$pr_num from $owner/$repo"
        exit 1
    }
    
    # Check if already exists
    if grep -q "#$pr_num " "$BACKLOG_FILE"; then
        log_warn "PR #$pr_num already tracked"
        return
    fi
    
    # Add to table
    sed -i "/|----|-------|--------|----------|-------|/a| #$pr_num | $title | open | medium | |" "$BACKLOG_FILE"
    log_info "Added PR #$pr_num to tracking: $title"
}

# Remove a PR from tracking
cmd_remove() {
    local pr_num
    pr_num=$(extract_pr_number "$1")
    [[ -z "$pr_num" ]] && { log_error "Usage: track-prs.sh remove <pr_number>"; exit 1; }
    
    init_backlog
    
    if grep -q "#$pr_num " "$BACKLOG_FILE"; then
        sed -i "/#$pr_num /d" "$BACKLOG_FILE"
        log_info "Removed PR #$pr_num from tracking"
    else
        log_warn "PR #$pr_num not found in tracking"
    fi
}

# Sync all PRs with GitHub
cmd_sync() {
    init_backlog
    
    log_info "Syncing PR status with GitHub..."
    
    # Read PRs and update status
    local tmp_file
    tmp_file=$(mktemp)
    
    # Preserve header
    head -3 "$BACKLOG_FILE" > "$tmp_file"
    echo "|----|-------|--------|----------|-------|" >> "$tmp_file"
    
    tail -n +4 "$BACKLOG_FILE" | while IFS='|' read -r pr title status priority notes _; do
        pr=$(echo "$pr" | tr -d ' ' | tr -d '#')
        [[ -z "$pr" ]] && continue
        
        # Get current status from GitHub
        local current_status
        current_status=$(gh pr view "$pr" --repo "$REPO_OWNER/$REPO_NAME" --json state -q '.state' 2>/dev/null) || {
            echo "| #$pr | $title | $status | $priority | $notes |" >> "$tmp_file"
            log_warn "Failed to fetch PR #$pr"
            continue
        }
        
        # Map state to status
        case "$current_status" in
            MERGED) current_status="merged" ;;
            CLOSED) current_status="closed" ;;
            OPEN)   current_status="open" ;;
        esac
        
        echo "| #$pr | $title | $current_status | $priority | $notes |" >> "$tmp_file"
        [[ "$status" != "$current_status" ]] && log_info "PR #$pr: $status -> $current_status"
    done
    
    mv "$tmp_file" "$BACKLOG_FILE"
    log_info "Sync complete"
}

# Watch a PR via GitHub CLI
cmd_watch() {
    local pr_url="$1"
    [[ -z "$pr_url" ]] && { log_error "Usage: track-prs.sh watch <pr_url>"; exit 1; }
    
    local pr_num
    pr_num=$(extract_pr_number "$pr_url")
    [[ -z "$pr_num" ]] && { log_error "Invalid PR reference: $pr_url"; exit 1; }
    
    gh pr watch "$pr_num" --repo "$REPO_OWNER/$REPO_NAME"
    log_info "Now watching PR #$pr_num"
}

# Unwatch a PR via GitHub CLI
cmd_unwatch() {
    local pr_num
    pr_num=$(extract_pr_number "$1")
    [[ -z "$pr_num" ]] && { log_error "Usage: track-prs.sh unwatch <pr_number>"; exit 1; }
    
    gh pr unwatch "$pr_num" --repo "$REPO_OWNER/$REPO_NAME"
    log_info "Stopped watching PR #$pr_num"
}

# Browse and pick PRs to track (interactive TUI)
cmd_pick() {
    local limit="${1:-20}"
    shift || true
    local selection="$*"  # Optional pre-selection
    
    # Source checkbox.sh for interactive selection
    # Try multiple paths for flexibility (including hidden .checkbox.sh)
    local checkbox_paths=(
        "$SCRIPT_DIR/checkbox.sh"
        "$SCRIPT_DIR/.checkbox.sh"
        "$(dirname "$SCRIPT_DIR")/checkbox.sh"
        "$(dirname "$SCRIPT_DIR")/.checkbox.sh"
        "/infra/skills/self-build/scripts/checkbox.sh"
        "/infra/skills/self-build/scripts/.checkbox.sh"
    )
    
    local checkbox_path=""
    for p in "${checkbox_paths[@]}"; do
        if [[ -f "$p" ]]; then
            checkbox_path="$p"
            break
        fi
    done
    
    if [[ -z "$checkbox_path" ]]; then
        log_error "checkbox.sh not found"
        return 1
    fi
    
    log_info "Fetching recent PRs from $REPO_OWNER/$REPO_NAME..."
    
    # Fetch recent open PRs
    local prs
    prs=$(gh pr list --repo "$REPO_OWNER/$REPO_NAME" --state open --limit "$limit" --json number,title,author --jq '.[] | "#\(.number) \(.title) by \(.author.login)"')
    
    if [[ -z "$prs" ]]; then
        log_warn "No open PRs found"
        return
    fi
    
    # Convert to pipe-separated for checkbox.sh
    local options
    options=$(echo "$prs" | tr '\n' '|')
    
    # Use checkbox.sh for interactive selection
    source "$checkbox_path" --options="$options" --multiple --index --message="Select PRs to track:"
    
    if [[ -z "$checkbox_output" ]]; then
        log_info "No PRs selected"
        return
    fi
    
    # Add selected PRs (checkbox_output contains indices)
    for idx in $checkbox_output; do
        local pr_num
        pr_num=$(echo "$prs" | sed -n "${idx}p" | grep -oE '#?[0-9]+' | head -1 | tr -d '#')
        if [[ -n "$pr_num" ]]; then
            cmd_add "$pr_num"
        fi
    done
}

# Show usage
cmd_help() {
    cat << EOF
track-prs.sh - Track upstream PRs

Usage: track-prs.sh <command> [args]

Commands:
  list              List all tracked PRs
  add <pr_url>     Add a PR to tracking
  remove <pr_num>  Remove a PR from tracking
  sync              Sync all PR status with GitHub
  pick [n]         Interactive PR picker (needs terminal)
  watch <pr_url>   Enable notifications for a PR
  unwatch <pr_num> Disable notifications for a PR

Environment:
  REPO_OWNER        Repository owner (default: nextlevelbuilder)
  REPO_NAME         Repository name (default: goclaw)
  GOCLAW_WORKSPACE Workspace directory (default: ~/.goclaw/workspace)

Examples:
  track-prs.sh add https://github.com/nextlevelbuilder/goclaw/pull/1234
  track-prs.sh sync
  track-prs.sh list
  track-prs.sh pick
  track-prs.sh pick 50
  track-prs.sh watch 1234
EOF
}

# Main
case "${1:-help}" in
    list)    cmd_list ;;
    add)     cmd_add "$2" ;;
    remove)  cmd_remove "$2" ;;
    sync)    cmd_sync ;;
    watch)   cmd_watch "$2" ;;
    unwatch) cmd_unwatch "$2" ;;
    pick)    cmd_pick "${2:-20}" ;;
    help|--help|-h) cmd_help ;;
    *)       log_error "Unknown command: $1"; cmd_help; exit 1 ;;
esac
