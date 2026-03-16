# Using GoClaw with Mise-en-place

GoClaw may be built, and launched either as a local binary or
as a Container. (Docker, Rootless Podman, or k8s).

[mise-en-place](https://mise.jdx.ai/) provides the means to manage these options using:

- Tooling
- Environment Variables
- Tasks

## Managing tooling

`mise` has an extensive registry of tools, and is able to install and manage
different versions, even locally built binaries.

Every time that the coder changes directory, `mise` recalculates `env.PATH` customizing
the set of available tools to the pinned versions specified for the project folder.

## Streamlining `docker-compose`

The 'env.COMPOSE_FILE' allows a series of `docker-compose` files to be combined.

Every time that the coder changes directory, `mise` recalculates other 
environment variables. In particular the coder's selection of `GOCLAW_MODULES`
is transformed into `env.COMPOSE_FILE` used by `docker compose`.

```bash
# postgres+gateway+selfservice+sandbox+browser+otel+tailscale+upgrade+vnstock-mcp
GOCLAW_MODULES = 'postgres+selfservice'


```

## Managing Secrets

Every time that the coder changes directory, `mise` decrypts secrets to make
them available locally. This allows the encrpted secrets to be managed at a
safe  distance from the code repository, or any active agents. 

## Tasks

[mise-en-place](https://mise.jdx.ai/) also provides the means to present
an interactive picker for selection of useful tasks.

```bash
$> mise run
Tasks
Select a task to run
❯ build:current                  Build binary (./build-current/goclaw)
  build:next                     Build goclaw binary (./build-next/goclaw)
  build:wip                      Build current branch with upstream PRs merged
  compose:build-sandbox          Build the goclaw-sandbox Docker image
  compose:services-list          List compose services
  git:mise-setup-prior-to-merge  Setup mise-data branch (while mise is not merged into main)
  git:pull-prs                   Merge upstream PRs (from branch name or mise/main.toml)
  git:track-prs                  Track and manage upstream PRs
  git:upstream-init              Add upstream remote
  git:upstream-to-main           Sync main with upstream (with confirmation)
  podman:enable                  Enable podman environment
  podman:ids-map                 List ids map
  switch:confirm                 Confirm current version, cancel auto-rollback
  switch:new                     Switch to next version (atomic: save, stop, switch, start)
  switch:rollback                Rollback to previous version / Setup auto-rollback
/ 
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| **Project** | | |
| `COMPOSE_PROJECT_NAME` | `$(basename "$PWD")` | Prefix for container/volume names |
| `PROJECT_UPSTREAM_URL` | `https://github.com/nextlevelbuilder/goclaw` | Upstream repository URL |
| `PROJECT_ORIGIN_URL` | `${PROJECT_UPSTREAM_URL}` | Origin/fork repository URL |
| `REPO_DIR` | `$PWD` | Repository directory |
| **Build** | | |
| `TARGETS` | `./cmd/goclaw` | Build targets (comma-separated) |
| `OUTPUT_DIR` | `build-current` | Build output directory (positional arg) |
| `AUTOROLLBACK_SECONDS` | `600` | Auto-rollback timer (10 min) |
| **Workspace** | | |
| `GOCLAW_HOME` | `~/.goclaw` | GoClaw data directory |
| `GOCLAW_WORKSPACE` | `~/.goclaw/workspace` | PR tracking workspace |
| **PR Tracking** | | |
| `REPO_OWNER` | `nextlevelbuilder` | Upstream repository owner |
| `REPO_NAME` | `goclaw` | Upstream repository name |
| **Secrets** | | |
| `GOCLAW_GATEWAY_TOKEN` | (required) | Gateway auth token (create via `./prepare-env.sh`) |
| `GOCLAW_ENCRYPTION_KEY` | (required) | Encryption key (create via `./prepare-env.sh`) |
| `GOCLAW_OPENROUTER_API_KEY` | - | OpenRouter API key |
| `GOCLAW_GEMINI_API_KEY` | - | Google Gemini API key |
| `GOCLAW_MINIMAX_API_KEY` | - | MiniMax API key |
| **Modules** | | |
| `GOCLAW_MODULES` | `postgres+selfservice` | Compose modules (`postgres+gateway+selfservice+sandbox+browser+otel+tailscale+upgrade:vnstock-mcp`) |



