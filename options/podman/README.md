# Podman Setup for GoClaw

Podman rootless server configuration and networking fixes.

## Quick Start

```bash
./setup.sh
```

## What We Learned

### DNS Resolution Issue

**Problem**: Docker's `127.0.0.11` DNS resolver doesn't work in Podman.

When GoClaw's nginx tries to resolve `goclaw` hostname, it fails because:
- Docker: Containers use Docker's embedded DNS at `127.0.0.11`
- Podman: Uses `aardvark-dns` listening on the network gateway IP

**Symptom**: `nginx: [emerg] host not found` in container logs.

**Solution**: Set `NGINX_DNS_RESOLVER` env var to podman's gateway IP (e.g., `10.89.1.1`).

The nginx image's entrypoint processes `*.template` files with envsubst, so the resolver is set at runtime.

### Podman Network Gateway IP

Podman's aardvark-dns listens on the bridge network gateway. To find it:

```bash
podman network inspect auto_default | grep gateway
# or
podman exec goclaw-ui cat /etc/resolv.conf
```

Common pattern: `10.89.0.1` or `10.89.1.1` (third octet may vary)

## Files

| File | Purpose |
|------|---------|
| `setup.sh` | Copies configs to `~/.config/containers/` |
| `config/containers.conf` | Rootless podman config (userns, group_add, umask) |
| `config/storage.conf` | Overlay storage driver at `/opt/storage` |
| `config/registries.conf` | Add docker.io as default search |
| `config/mise.podman.toml` | Mise podman environment settings |
| `config/miserc.toml` | Mise config activation |
| `podman-network-fix.yml` | Compose overlay for network settings |
| `podman-user-fix.yml` | User namespace fixes |

## Usage

### With Docker Compose
```bash
# Include the network fix overlay
docker compose -f docker-compose.yml \
  -f docker-compose.postgres.yml \
  -f options/podman/podman-network-fix.yml \
  up -d
```

### With setup.sh
```bash
cd options/podman
./setup.sh
# Then use compose normally - setup.sh copies overlays to compose.d/
# ./prepare-compose.sh      - Compiles COMPOSE_FILE from compose.d/*.yml
```

## Troubleshooting

### nginx fails to resolve goclaw
Check logs: `podman logs goclaw-ui`
Verify resolver: `podman exec goclaw-ui nginx -T | grep resolver`

### Can't access volume data
Podman rootless uses overlayfs. Files may be owned by root inside container but appear as numeric UID outside.
Use `podman unshare` to access or check with `podman exec stat /path`

### Database permissions
Postgres runs as UID 70 inside container. With `keep-id` in containers.conf, using `0:0` inside the container maps to the external owner:
```bash
# Fix ownership (0:0 maps to external UID via keep-id)
podman unshare chown -R 0:0 /srv/your-volume
```

## See Also

- [Podman Networking](https://docs.podman.io/en/latest/markdown/podman.1.html#network)
- [aardvark-dns](https://github.com/containers/aardvark-dns)
- [Nginx Resolver](https://nginx.org/en/docs/http/ngx_http_core_module.html#resolver)
