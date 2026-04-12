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
| `setup.sh` | Copies configs to `~/.config/containers/` |
| `config/containers.conf` | data at /srv (userns=keep-id, group_add) |
| `config/storage.conf` | Overlay storage driver at `/opt/storage` |
| `config/registries.conf` | Add docker.io as default search |
| `config/mise.podman.toml` | Mise podman environment settings |
| `config/miserc.toml` | Mise config activation |
| `podman-network-fix.yml` | Compose overlay for network settings |
| `podman-user-fix.yml` | User namespace fixes |

### Usage

The setup script copies compose overlays to `compose.d/`, and `prepare-compose.sh` generates the `COMPOSE_FILE` from them:

```bash
cd options/podman
./setup.sh                 # copy yml files to compose.d/
cd ../..
./prepare-compose.sh      # build COMPOSE_FILE from compose.d/*.yml
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

---

## Self-Building Container

A container that builds its own layers. No CI/CD pipeline needed for adding modules.

See [SELF_BUILDING.md](./SELF_BUILDING.md) for full documentation.

### Quick Overview

The container contains buildah and builds its own layers. An agent can:

```bash
make ctr-python           # add python module
make ctr-commit-next      # commit as :v2
```

### Why

- **No external build system** for module additions
- **No Dockerfile changes** to add packages
- **Container evolves** as agent discovers needs
- **Blue-green** without registry complexity

### Files

```
goclaw/
├── Makefile               # modular build system (included in container)
├── entrypoint.sh          # shell entrypoint
└── entrypoint.execline    # execline entrypoint (optional)
```

---

## See Also

- [Podman Networking](https://docs.podman.io/en/latest/markdown/podman.1.html#network)
- [aardvark-dns](https://github.com/containers/aardvark-dns)
- [Nginx Resolver](https://nginx.org/en/docs/http/ngx_http_core_module.html#resolver)
- [Self-Building Container](./SELF_BUILDING.md)
