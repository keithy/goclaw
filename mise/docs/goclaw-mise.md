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

Every time that the coder changes directory, `mise` recalculates `PATH` customizing
the set of available tools to the versions specified.

## Streamlining `docker-compose`

The env.COMPOSE_FILE allows a series of `docker-compose` files to be combined.

Every time that the coder changes directory, `mise` recalculates other 
environment variables. In particular the coder's selection of `GOCLAW_MODULES`
is transformed into `env.COMPOSE_FILE` used by `docker compose`.

## Managing Secrets

Every time that the coder changes directory, `mise` decrypts secrets to make
them available locally. This allows the encrpted secrets to be managed at a
safe  distance from the code repository, or any active agents. 

## Tasks

[mise-en-place](https://mise.jdx.ai/) also provides the means to present
an interactive picker for selection of useful tasks.

'''bash
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
| `DOCKER_CMD` | `docker` | CLI command (`podman` or `docker`) |
| `PODMAN_COMPOSE_WARNING_LOGS` | `false` | Suppress podman-compose warnings |


## Troubleshooting


### Socket permission denied

Check socket exists and permissions:
```bash
ls -la /run/user/$UID/podman/podman.sock
```
