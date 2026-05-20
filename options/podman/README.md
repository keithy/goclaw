# Podman Setup for GoClaw

## Podman Configuration

### Quick Start

```bash
./setup.sh
```

### DNS Resolution Issue

**Problem**: Docker's `127.0.0.11` DNS resolver doesn't work in Podman.

When GoClaw's nginx tries to resolve `goclaw` hostname, it fails because:
- Docker: Containers use Docker's embedded DNS at `127.0.0.11`
- Podman: Uses `aardvark-dns` listening on the network gateway IP

**Symptom**: `nginx: [emerg] host not found` in container logs.

**Solution**: No manual resolver configuration needed. The nginx image automatically uses `/etc/resolv.conf` via `NGINX_ENTRYPOINT_LOCAL_RESOLVERS=1` in `docker-compose.selfservice.yml`.

### Podman Network Gateway IP

Podman's aardvark-dns listens on the bridge network gateway. To find it:

```bash
podman network inspect auto_default | grep gateway
# or
podman exec goclaw-ui cat /etc/resolv.conf
```

Common pattern: `10.89.0.1` or `10.89.1.1` (third octet may vary)

### Files

| File | Purpose |
|------|---------|
| `setup.sh` | Copies `config/containers/` to `~/.config/containers/` |
| `config/containers/` | Podman config directory |
| `config/containers/containers.conf` | userns=keep-id, group_add |
| `config/containers/storage.conf` | Overlay storage driver at `/opt/storage` |
| `config/containers/registries.conf` | Add docker.io as default search |
| `config/containers/oci-hook.d/poststop` | ~~Auto-commit on exit 42~~ (removed - use keithy/sensible)
| `podman+network-fix.yml` | Compose overlay for network settings |
| `podman+user-fix.yml` | User namespace fixes |

### Usage

The setup script recommends overlay paths. Add them to your COMPOSE_FILE:

```bash
cd options/podman
./setup.sh
# Note the paths shown, then:
export COMPOSE_FILE=docker-compose.yml:$GOCLAW_DIR/options/podman/podman+network-fix.yml:$GOCLAW_DIR/options/podman/podman+user-fix.yml
podman compose up -d
```

### Troubleshooting

#### nginx fails to resolve goclaw
Check logs: `podman logs goclaw-ui`
Verify resolver: `podman exec goclaw-ui nginx -T | grep resolver`

#### Can't access volume data
Podman rootless uses overlayfs. Files may be owned by root inside container but appear as numeric UID outside.
Use `podman unshare` to access or check with `podman exec stat /path`

#### Database permissions
Normally Postgres expects the container to be started as root UID 0, and later it
switches the postgres process to run as UID postgres(999). 

Alternatively if it finds that it has been started as another UID, it will use
that UID, and attempt to update the permissions of all files to match that UID.

With `keep-id` set, the container runs rootless as the host user id.
the attempt to change permissions will likely fail due to lack of
permissions, but as long as the persisted files are owned by the
user it should works.

```
# permissions fix
chown -R $(id -u):$(id -g) /srv/$COMPOSE_PROJECT_NAME_postgres-data
```

```
# Fix ownership (0:0 maps to external UID via keep-id)
podman unshare chown -R 0:0 /srv/your-volume
```


