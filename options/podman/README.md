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

### Files

| File | Purpose |
|------|---------|
| `setup.sh` | Copies `config/containers/` to `~/.config/containers/` |
| `config/containers/` | Podman config directory |
| `config/containers/containers.conf` | userns=keep-id, group_add |
| `config/containers/storage.conf` | Overlay storage driver at `/opt/storage` |
| `config/containers/registries.conf` | Add docker.io as default search |
| `config/containers/oci-hook.d/poststop` | Auto-commit on exit 42 |
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
Postgres runs as UID 70 inside container. With `keep-id` in containers.conf, using `0:0` inside the container maps to the external owner:
```bash
# Fix ownership (0:0 maps to external UID via keep-id)
podman unshare chown -R 0:0 /srv/your-volume
```

### OCI Poststop Hook (Auto-Commit)

Container exits with code **42** to trigger auto-commit. The poststop hook commits the running container's filesystem to an image.

**How it works:**
1. Agent runs inside container, makes changes
2. Agent exits with code 42
3. Container stops, hook fires
4. Hook runs `podman commit` — container's changes are saved
5. Start container again — now has the new layers

**Hook location:** `config/containers/oci-hook.d/poststop`

**Usage:**
```bash
# Inside container - when ready to save state
exit 42

# On host - container is now committed
podman images | grep goclaw
```

**Why exit 42?**
- Normal exit (0) = just stop
- Error exit (1) = something went wrong
- 42 = "save my work" signal

---

## See Also

- [Podman Networking](https://docs.podman.io/en/latest/markdown/podman.1.html#network)
- [aardvark-dns](https://github.com/containers/aardvark-dns)
- [Nginx Resolver](https://nginx.org/en/docs/http/ngx_http_core_module.html#resolver)
- [Self-Building Container](./SELF_BUILDING.md)
