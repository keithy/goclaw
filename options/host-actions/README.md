# Host Actions

A queue-based system for dispatching actions from containers to host for execution using execline.

## How it works

1. Container writes action to `/app/data/.runtime/host-actions/queue/<ts>-<action>`
2. Host watches queue via volume mount at `/srv/.../host-actions/queue`
3. Dispatcher processes queue files in reverse timestamp order
4. Runs `execlineb "$queue_file"` with `actions/` on PATH
5. Action script found on PATH, executes on host

## Directory structure

```
host-actions/
├── README.md
├── setup-systemd.sh
├── dispatch.sh
├── host-action.yml
├── bin/
│   └── host-action           # Container writes to queue
├── actions/                 # Action scripts on PATH
│   ├── commit               # commit <container> [tag]
│   ├── restart             # restart <container>
│   ├── switch              # switch <container> <from_tag> [to_tag]
│   ├── compile             # build goclaw
│   └── update              # sync upstream + merge PRs
└── queue/                   # (volume mount point)
    └── done/                # Completed actions with output
```

## Usage

```bash
# Inside container
host-action '... arbitrary execlineb script ...' e.g.
host-action <action> <container> [args...]

# Examples
host-action commit mycontainer next
host-action switch mycontainer current previous
host-action switch mycontainer next current
host-action restart mycontainer

The queue file content is the full execline command to execute on host:
- `commit mycontainer next` → runs `actions/commit` with `mycontainer` as `$1`, `next` as `$2` (defaults to `current`)

## Setup

```bash
./setup-systemd.sh
systemctl --user daemon-reload
systemctl --user enable --now host-action.path
```

## Why execline

execline provides safer script execution than shell:

- **No shell interpolation** — variables use `import -env` or `withenv`, not `$VAR`
- **No command chaining** — uses `&&` `||` `;` builtins, not shell operators
- **Builtin-only control flow** - `if`, `try`, `background`, etc. are builtins
- **No shell escape** — `execlineb "$file"` not `-c "$(cat)"`, prevents injection
- **Shebang honored** — action scripts can use any interpreter (`#!/bin/sh`, `#!/bin/execlineb`)

## Security model

### Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `HOST_ACTIONS_PATH` | `$PATH` | Append to PATH (actions dir always first) |
| `HOST_ACTIONS_TIMEOUT` | `300` | Max seconds per action |
| `HOST_ACTIONS_WHITELIST` | (none) | Space-separated allowed actions |
| `HOST_ACTIONS_BLACKLIST` | (none) | Regex pattern - reject matches |
| `HOST_ACTIONS_SCRIPTS` | `true` | `false` to reject `{` blocks |

### Whitelist

Only allow specific actions:
```bash
HOST_ACTIONS_WHITELIST="commit restart switch compile update" ./dispatch.sh
```

### Blacklist

Reject scripts matching regex:
```bash
HOST_ACTIONS_BLACKLIST='\{' ./dispatch.sh   # reject execline blocks
HOST_ACTIONS_BLACKLIST='rm\s+-rf' ./dispatch.sh
```

### Script-only mode

Restrict to simple command scripts (no execline blocks):
```bash
HOST_ACTIONS_SCRIPTS=false ./dispatch.sh
```

### PATH hardening

Actions dir always prepended. Extend with additional paths:
```bash
HOST_ACTIONS_PATH="/bin:/usr/bin" ./dispatch.sh
```

### Rejected folder

Non-compliant scripts moved to `rejected/` with reason in header.

### Environment file

Systemd service sources `${GOCLAW_DIR}/.env`. Set vars in `.env`:

```bash
HOST_ACTIONS_WHITELIST=commit restart switch compile update
HOST_ACTIONS_TIMEOUT=300
HOST_ACTIONS_BLACKLIST='\{'
HOST_ACTIONS_SCRIPTS=false
```

## Entrypoint integration

The goclaw entrypoint can call `host-action` when installers run:
```sh
if command -v host-action >/dev/null 2>&1; then
    host-action commit "$(hostname)"
fi
```

## Compose overlay

Add to compose command:
```bash
podman compose -f options/podman/goclaw.yml -f options/host-actions/host-action.yml up -d
```

## Alternatives considered

### PostgreSQL NOTIFY/LISTEN

Could have used Postgres `NOTIFY`/`LISTEN` for container→host signaling:

1. Container: `NOTIFY host_actions, 'commit:<container>'`
2. Host: `LISTEN host_actions` via `pg_recvlogical` or a Go listener

**Pros:** Native Postgres, no filesystem hacks, transactional
**Cons:** Requires DB connection from host, adds complexity, still needs a runner to execute host commands

### Unix socket + nc/netcat

Container writes to a Unix socket, host listens:
```bash
# Container
echo "commit" | nc -U /run/host-actions.sock

# Host
nc -l -k -U /run/host-actions.sock | while read cmd; do ...; done
```

**Pros:** Simple, no polling
**Cons:** Requires socket setup, permission handling, more fragile

### Why file-based queue

File-based queue was chosen for simplicity, portability, and easy debugging (ls the directory to see pending actions).
