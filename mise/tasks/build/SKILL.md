---
name: self-build
description: Build, test, and track upstream PRs for PicoClaw with safe rollout.
license: MIT
metadata:
  author: keithy@consultant.com
  version: 1.1.0
---
# self-build

Build PicoClaw, track upstream PRs, and contribute with safe rollout.

## Overview

When working with external open-source projects where changes must be submitted via PRs, you need a way to:
1. Track interesting PRs from the upstream
2. Monitor their status
3. Know when to merge/update your derived version

## Quick Start

```bash
exec "skills/self-build/scripts/mise-init.sh"
```

This sets up:
- `mise-data` branch (orphan) for mise configuration
- `mise/` worktree with branch-specific configs
- Build tasks: `switch`, `rollback`, `confirm`, `build-current`, `build-next`

## Scripts

| Script | Purpose |
|--------|---------|
| `mise-init.sh` | Setup mise with branch-specific configs via git worktree |
| `upstream-init.sh` | Add upstream remote (idempotent) |
| `upstream-to-main.sh` | Sync main branch from upstream |
| `track-prs.sh` | Track and monitor upstream PRs |
| `build-branch.sh` | Build current branch with custom PRs merged |

## Mise Tasks (installed by `mise-init.sh`)

After running `mise-init.sh`, these tasks are available:

| Task | Description |
|------|-------------|
| `mise run switch` | Atomic switch to new build (build-next → build-current) |
| `mise run rollback` | Rollback to previous version (build-prev → build-current) |
| `mise run confirm` | Confirm current version, cancel auto-rollback timer |
| `mise run build-current` | Build to `./build-current/` |
| `mise run build-next` | Build to `./build-next/` |
| `mise run pull-prs` | Merge upstream PRs (from branch name or `mise/main.toml`) |
| `mise run upstream-init` | Add upstream remote |
| `mise run upstream-to-main` | Sync main branch from upstream |
| `mise run track-prs` | Track PRs (sync, list, add, remove, watch) |

---

## Mise Setup (`mise-init.sh`)

Manage branch-specific mise configs using a git worktree and symlinks.

### What It Does

1. **Creates orphan branch** `mise-data` for mise configs
2. **Creates worktree** at `mise/` on `mise-data` branch
3. **Creates base config** `mise/config.toml` with project name
4. **Creates branch config** `mise/<current-branch>.toml` for your branch
5. **Creates symlink** `mise/config.local.toml` → current branch config
6. **Installs git hook** `post-checkout` to auto-update symlink on branch switch
7. **Copies build tasks** to `mise/tasks/` for atomic switch/rollback

### Usage

```bash
exec "skills/self-build/scripts/mise-init.sh"
```

### Build Directories

The setup uses three build directories for safe rollout:

| Directory | Purpose |
|-----------|---------|
| `build-current/` | Currently running production build |
| `build-next/` | New build being tested |
| `build-prev/` | Previous build for rollback |

### Atomic Switch Workflow

```bash
# Build new version to test
mise run build-next

# Test the new build...
# When ready, atomic switch:
mise run switch

# Service stops → build-next becomes build-current → service starts
# If issues, auto-rollback triggers after 10 minutes

# Confirm if all is well (cancels auto-rollback):
mise run confirm

# Or manually rollback:
mise run rollback
```

### Switching Branches

The `post-checkout` hook automatically updates the symlink when you switch branches:

```bash
git checkout some-other-branch
# mise/config.local.toml now points to some-other-branch.toml
```

### Manual Branch Config

Edit configs in the worktree:
```bash
cd mise
# Edit or add <branch>.toml
git add .
git commit -m "Add branch config"
```

### Example Config (`mise/config.toml`)

```toml
[env]
PROJECT_NAME = "goclaw"

[tools]
go = "latest"

[tasks.dev]
run = "make run"
```

Branch-specific configs are in `mise/<branch>.toml`. The `mise/config.local.toml` symlink points to the current branch config.

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PROJECT_NAME` | `$(basename "$PWD")` | Project name for config |
| `REPO_DIR` | `$PWD` | Repository directory |
| `TARGETS` | `./cmd/goclaw` | Build targets (comma-separated) |
| `AUTOROLLBACK_SECONDS` | `600` | Auto-rollback timer (10 min) |

---

## Upstream Remote (`upstream-init.sh`)

Add the upstream remote (idempotent - safe to run multiple times).

**Usage:** `exec "skills/self-build/scripts/upstream-init.sh"`

---

## Sync From Upstream (`upstream-to-main.sh`)

Fetch and merge from upstream main branch.

**Usage:** `exec "skills/self-build/scripts/upstream-to-main.sh"`

---

## Build With PRs (`build-branch.sh`)

Build the current branch with custom PRs merged in.

### PR Sources (combined)

1. **Branch name**: Create a branch like `main+1038+1097` - PRs extracted from name
2. **mise/main.toml**: Add PRs to supplement branch name (without renaming branch)

Both sources are combined - you can use branch name for experimental PRs and config for stable ones.

### Configuration

Option 1: Branch name
```bash
git checkout -b main+1038+1097
```

Option 2: Add to `mise/main.toml`
```toml
[build]
prs = ["1038", "1042"]
```

### Usage

```bash
exec "skills/self-build/scripts/build-branch.sh"
```

This will:
1. Fetch and merge upstream/main
2. Fetch and merge PRs from branch name
3. Fetch and merge PRs from main.toml config
4. Build the result

### Example Workflow

```bash
# Method 1: Branch name for one-off builds
git checkout -b main+1038+1097
exec "skills/self-build/scripts/build-branch.sh"

# Method 2: Config for stable PRs (in mise/main.toml)
# [build]
# prs = ["1038", "1097"]
```

## Upstream Management (`setup-upstream.sh`)

Configure remotes for the upstream repo and sync your main branch.

### Actions via `setup-upstream.sh`

**Usage:** `exec "skills/self-build/scripts/setup-upstream.sh [command] [args]"`

| Command | Description |
|---------|-------------|
| `init` | Full setup: add upstream + fetch all |
| `upstream` | Add/update upstream remote |
| `fork <url>` | Add/update fork remote |
| `fetch` | Fetch all remotes |
| `sync [branch]` | Sync local branch from upstream (default: main) |
| `remotes` | Show current remotes |

### Examples

- **Initial setup:**
  ```
  exec "skills/self-build/scripts/setup-upstream.sh init"
  exec "skills/self-build/scripts/setup-upstream.sh fork git@github.com:yourname/goclaw.git"
  ```

- **Sync main from upstream:**
  ```
  exec "skills/self-build/scripts/setup-upstream.sh sync main"
  ```

- **Check remotes:**
  ```
  exec "skills/self-build/scripts/setup-upstream.sh remotes"
  ```

---

## PR Tracking (`track-prs.sh`)

This skill provides a helper script `scripts/track-prs.sh` for managing PR tracking.

### Configuration

Create a `PR_BACKLOG.md` file in your workspace (e.g., `~/.goclaw/workspace/PR_BACKLOG.md`):

```markdown
# PR Backlog

| PR | Title | Status | Priority | Notes |
|----|-------|--------|----------|-------|
| #1234 | Feature X | open | high | want this |
| #5678 | Fix Y | merged | medium | backport later |
```

### Actions via `track-prs.sh`

**Usage:** `exec "skills/self-build/scripts/track-prs.sh [action] [args]"`

| Action | Description |
|--------|-------------|
| `sync` | Fetch latest status of all tracked PRs from GitHub |
| `list` | List all tracked PRs with current status |
| `add <pr_url>` | Add a new PR to the tracking file |
| `remove <pr_number>` | Remove a PR from tracking |
| `watch <pr_url>` | Enable notifications for a PR (via gh) |
| `unwatch <pr_number>` | Disable notifications for a PR |

### Examples

- **Add a PR to track:**
  ```
  exec "skills/self-build/scripts/track-prs.sh add https://github.com/nextlevelbuilder/goclaw/pull/1234"
  ```

- **Sync all PR status:**
  ```
  exec "skills/self-build/scripts/track-prs.sh sync"
  ```

- **List tracked PRs:**
  ```
  exec "skills/self-build/scripts/track-prs.sh list"
  ```

- **Watch a PR for updates:**
  ```
  exec "skills/self-build/scripts/track-prs.sh watch https://github.com/nextlevelbuilder/goclaw/pull/1234"
  ```

## Workflow

1. **Find interesting PRs** in the upstream repo
2. **Add them to tracking** with `track-prs.sh add <url>`
3. **Watch for updates** with `track-prs.sh watch <url>` (uses GitHub CLI)
4. **Periodically sync** with `track-prs.sh sync` to get latest status
5. **Merge when ready** - update your local fork when desired PRs are merged

## Setup Requirements

- **GitHub CLI** (`gh`) installed and authenticated
- Fork of goclaw on GitHub

### Authenticate GitHub CLI

```bash
gh auth login
```

---

## Full Workflow

### 1. Initial Setup

```bash
# Setup mise with branch-specific configs
exec "skills/self-build/scripts/mise-init.sh"

# Add upstream remote
exec "skills/self-build/scripts/upstream-init.sh"
# Or with fork:
exec "skills/self-build/scripts/setup-upstream.sh init"
exec "skills/self-build/scripts/setup-upstream.sh fork git@github.com:yourname/goclaw.git"
```

### 2. Track Interesting PRs

```bash
# Add PRs to track
exec "skills/self-build/scripts/track-prs.sh add https://github.com/nextlevelbuilder/goclaw/pull/1234"
exec "skills/self-build/scripts/track-prs.sh watch 1234"
```

### 3. Regular Maintenance

```bash
# Sync main from upstream
exec "skills/self-build/scripts/upstream-to-main.sh"

# Update PR status
exec "skills/self-build/scripts/track-prs.sh sync"
exec "skills/self-build/scripts/track-prs.sh list"
```

### 4. Branch-Specific Mise Configs

```bash
# Create branch config
cd mise
echo '[env]
MY_VAR = "value"' > my-feature.toml

# Switch to use it
ln -sf my-feature.toml config.local.toml

# Commit the config
git add my-feature.toml config.local.toml
git commit -m "Add my-feature config"

# Now mise uses this config
mise run dev
```

---

## Related Skills

- **self-config** - Safely update your goclaw configuration
- **self-service-systemd** - Run goclaw as a systemd service
