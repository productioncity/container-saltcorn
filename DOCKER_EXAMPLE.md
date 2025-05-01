# 🐳 Saltcorn “Kitchen-Sink” Swarm Stack - Deep-Dive Explainer
*Last updated&nbsp;2025-05-01*

> **Read me first**
> This stack is intentionally _opinionated_ and _highly specialised_.
> • It expects a running **Docker Swarm** cluster.
> • It is wired for **Traefik** edge-routing, **GlusterFS** volumes, IPv6-aware overlay networks, Postgres with geospatial & time-series extensions, automated backups _and more_.
>
> Almost certainly you **cannot** copy-paste it and press “up”.
> Treat it as a **reference implementation**: dissect the pieces you need, then craft a compose file that matches _your_ infrastructure.

---

## 📚  Table of Contents
1. [Architecture Overview](#architecture-overview)
2. [Prerequisites](#prerequisites)
3. [.env File Walk-through](#env-file-walk-through)
4. [Network Topology](#network-topology)
5. [Service-by-Service Breakdown](#service-by-service-breakdown)
   * [Saltcorn](#1-saltcorn)
   * [Postgres (+extensions)](#2-postgres-extended)
   * [Automated Backup Side-car](#3-postgres-backup)
   * [pgAdmin GUI](#4-pgadmin)
6. [Volumes & Persistence](#volumes--persistence)
7. [Adapting the Example](#adapting-the-example)
8. [Security Notes](#security-notes)
9. [Further Reading](#further-reading)

---

## Architecture Overview

```text
        ┌───────────────┐               ┌───────────────┐
        │   Internet    │               │   Developers  │
        └──────┬────────┘               └────────┬──────┘
               ▼                                  ▼
        ┌───────────────┐               ┌────────────────┐
        │   Traefik     │ ← overlay →   │  Saltcorn      │
        │  (proxy)      │──────────────▶│  container     │
        └───────────────┘               └────────┬───────┘
               ▲                                  │
               │ HTTPS / HTTP3                    │ psql
               │                                  ▼
        ┌───────────────┐               ┌────────────────┐
        │    Clients    │               │  Postgres      │
        └───────────────┘               │ (PostGIS +     │
                                        │  TimescaleDB)  │
                                        └────────┬───────┘
                                                 │ pg_dump
                                                 ▼
                                      ┌──────────────────────┐
                                      │  Backup side-car     │
                                      └──────────────────────┘
```

*Every coloured arrow is an **overlay network hop**; local host-to-container
loops are omitted for clarity.*

---

## Prerequisites

| Requirement | Why it matters | Docs |
|-------------|---------------|------|
| Docker **20.10+** with **Swarm mode** | The `deploy:` section in each service only works under Swarm. | <https://docs.docker.com/engine/swarm/> |
| **Traefik v3** running in the `proxy` network | The stack publishes _zero_ ports - all ingress is handled by Traefik via labels. | <https://doc.traefik.io/traefik/> |
| **GlusterFS** (or alternative multi-node volume driver) | The example mounts persistent data via `driver: glusterfs` so that any Swarm node can host a replica. | <https://docs.gluster.org/> |
| **Valid public DNS** for `${APP_DOMAIN}` | Traefik’s ACME resolver needs to prove domain ownership to issue certs. | Your DNS provider |
| Outbound Internet | Build-time `apt`, `npm` and `curl` calls download packages and init scripts. | — |

> Tip: experimenting on a single machine?
> Disable Swarm-only keys (`deploy`, `endpoint_mode`, `placement`) and swap overlay networks for default bridge mode.

---

## .env File Walk-through

The file **`.env.docker-swarm-compose`** is loaded by Compose/Shell.
Below are the key groups you should customise:

| Variable(s) | Purpose | Example |
|-------------|---------|---------|
| `APP_DOMAIN`, `APP_SITE`, `APP_SITE_RESOLVER`, `APP_KEY` | Traefik routing & Saltcorn session secret | `mysite.example`, `mysite`, `cloudflare`, _(generate secret)_ |
| PostgreSQL version triplet | Pin the PostGIS image (`postgis/postgis:X-Y.Z`) | `17 3 5` → `postgis/postgis:17-3.5` |
| `GLUSTER_VOLUME_*` | Remote volume names. Change or remove if you’re not using Gluster. | `mysite_saltcorn_postgres` |
| `POSTGRES_*` | Credentials. **Never** commit real secrets. | `POSTGRES_PASSWORD=superSecret` |

_🚨 **Don’t** commit real passwords/TLS keys - keep them in an `.env` file that is **git-ignored**._

---

## Network Topology

```yaml
networks:
  proxy:
    name: proxy          # external -> Traefik already joined
    driver: overlay
    external: true

  backend:
    driver: overlay      # private east/west traffic
```

*Two* overlay networks are used:

1. **proxy** - shared with Traefik for public ingress.
2. **backend** - service-only network; Postgres isn’t exposed to the edge.

If you’re on **classic `docker-compose`** (single host), simply omit the networks block or let Compose create a default network.

---

## Service-by-Service Breakdown

### 1. Saltcorn

```yaml
saltcorn:
  image: ghcr.io/productioncity/saltcorn:latest
  networks: [proxy, backend]
  environment:
    - PGHOST=postgres-${APP_SITE}
    - SALTCORN_FILE_STORE=/filestore
    - PUID=1000
    - PGID=1000
  volumes:
    - filestore:/filestore
  labels:  # Traefik magic (abridged)
    - traefik.enable=true
    - traefik.http.routers.${APP_SITE}-https.rule=(Host(`${APP_DOMAIN}`)…)
    - traefik.http.routers.${APP_SITE}-https.tls.certresolver=${APP_SITE_RESOLVER}
```

Key points
| Aspect | Explanation |
|--------|-------------|
| **Image** | Signed multi-arch image from this repo - `latest` alias resolves to Saltcorn 1.1.4 on Node 23-slim. |
| **Networks** | Joins both overlay networks: `backend` for DB traffic and `proxy` so Traefik can reach port 3000. |
| **UID/GID remapping** | Pass `PUID`/`PGID` so uploaded files inside `/filestore` are owned by your host user when mounted via bind. |
| **Health-check** | Tiny Python script performs an HTTP `GET /` inside the container every 30 s. Swarm can restart the task if Saltcorn misbehaves. |
| **Traefik labels** | Declare two routers (`-http`, `-https`) plus middlewares (`gzip`, `https-redirect`, `limit`, …). Remove or tailor to your Traefik setup. |

> **Serving static files**
> By default Saltcorn stores uploads _inside the container_.
> Mount a persistent volume (`filestore`) and set `SALTCORN_FILE_STORE` to avoid data loss on upgrades.

---

### 2. Postgres (extended)

```yaml
postgres:
  image: postgis/postgis:${POSTGRES_MAJOR_VERSION}-${POSTGRES_MINOR_VERSION}.${POSTGRES_PATCH_VERSION}
  entrypoint: [ "bash", "-c", "<long-script>" ]
  volumes:
    - postgres:/var/lib/postgresql/data
```

What makes this image special?

| Layer | Details |
|-------|---------|
| **Base** | [postgis/postgis](https://hub.docker.com/r/postgis/postgis) - Postgres with PostGIS baked-in. |
| **Run-time addons** | The entrypoint script installs: <br>• `pg_cron` - scheduled jobs inside Postgres (<https://github.com/citusdata/pg_cron>) <br>• `plpython3u` - untrusted Python UDFs <br>• `TimescaleDB 2.x` + `timescaledb-toolkit` (<https://docs.timescale.com/>) |
| **Initialisation hooks** | `docker-entrypoint-initdb.d/*.sql` scripts enable extensions and import Saltcorn’s sample data (fetched from GitHub). |
| **Auto-tuning** | After first start the script executes `timescaledb-tune --yes`, then sleeps 60 s to ensure Postgres accepts the new config. |
| **Shared Preload** | Inserts `pg_cron` into `shared_preload_libraries` and sets `cron.database_name` automatically. |
| **Health-check** | Runs `pg_isready` _and_ validates PostGIS extension exists. |

> Want a vanilla cluster?
> * Remove the entire `entrypoint` override - you’ll fall back to the upstream PostGIS image’s default behaviour.
> * If you don’t need PostGIS at all, switch to `postgres:XX-alpine` and trim any extension calls.

---

### 3. Postgres-Backup
A tiny side-car that uses the same PostGIS image but runs **`pg_dumpall` every N hours**.

```yaml
postgres-backup:
  environment:
    - BACKUP_INTERVAL=12   # hours
    - REMOVE_BEFORE=60     # days - delete old dumps
  volumes:
    - postgres:/backups    # share Gluster volume
  command: |
    until pg_isready -h postgres -U $POSTGRES_USER; do sleep 60; done
    while true; do
      pg_dumpall … > dump.sql && gzip dump.sql
      find /backups -mtime +$REMOVE_BEFORE -delete
      sleep ${BACKUP_INTERVAL}h
    done
```

Feel free to replace this DIY loop with a dedicated tool such as
[pgBackRest](https://pgbackrest.org/) or
[Barman](https://www.pgbarman.org/).

---

### 4. pgAdmin
A browser-based DBA console.
Runs in the **backend** + **proxy** networks so Traefik can route `pgadmin.${APP_DOMAIN}` over HTTPS.

Interesting bits:
* `PGADMIN_SERVER_JSON_FILE` - pre-loads a connection pointed at the service hostname, saving you manual clicks.
* Stores its SQLite settings DB on the same Gluster volume (`postgres`), simplifying backup.

---

## Volumes & Persistence

```yaml
volumes:
  postgres:
    driver: glusterfs
    name: ${GLUSTER_VOLUME_POSTGRES}
  filestore:
    driver: glusterfs
    name: ${GLUSTER_VOLUME_FILESTORE}
```

* **GlusterFS** guarantees the volume is reachable by any Swarm node that might
  run the task after rescheduling.
* On a single host you can switch to the default `local` driver:

```yaml
volumes:
  postgres:
  filestore:
```

> ⚠️ The stack **does not** mount the Saltcorn application directory itself; upgrades are handled by replacing the container image.

---

## Adapting the Example

| Scenario | How to tweak |
|----------|--------------|
| **Plain docker-compose** (no Swarm) | Delete every `deploy:` block, drop all `endpoint_mode`, `placement`, `update_config`, `rollback_config` keys. |
| **No Traefik** | Bind container ports instead: <br>`ports: ["3000:3000"]` under `saltcorn` and `ports: ["80:80"]` for `pgadmin`. Remove all `traefik.*` labels and the `proxy` network. |
| **No IPv6** | Remove `sysctls: net.ipv6.conf.all.disable_ipv6=0`. |
| **No GlusterFS** | Replace `driver: glusterfs` with `local` or a driver supported by your environment. |
| **Bring-your-own Postgres** | Delete `postgres` & `postgres-backup` services. Update `PGHOST`, `PGPORT`, `PGUSER`, etc. in Saltcorn’s environment to point to your cluster. |
| **Disable extensions** | Strip the `apt-get install` lines and `.sql` scripts from the Postgres `entrypoint`. |

---

## Security Notes
1. **Secrets** - Store real credentials in Docker Swarm secrets or an external
   vault. The example keeps everything in `.env` purely for clarity.
2. **TLS termination** - Traefik handles ACME certificates; ensure ports 80/443
   are reachable from the Internet and firewall rules allow Let’s Encrypt
   validation.
3. **User namespaces** - Mapping `PUID`/`PGID` to your host account avoids
   root-owned files when using bind-mounts. See Docker’s
   [user namespace remap](https://docs.docker.com/engine/security/userns-remap/) for hardened setups.
4. **Database super-user in container** - Running Postgres as the default
   `postgres` Linux user is standard practice, but remember to firewall the
   `backend` network from untrusted workloads.
5. **Resource limits** - CPU/RAM caps (`deploy.resources.limits`) are examples
   only. Adjust to match real capacity.

---

## Further Reading

| Topic | Official Docs |
|-------|---------------|
| Docker Swarm | <https://docs.docker.com/engine/swarm/> |
| Compose File Reference | <https://docs.docker.com/compose/compose-file/> |
| Saltcorn | <https://github.com/saltcorn/saltcorn> |
| Traefik | <https://doc.traefik.io/traefik/> |
| Postgres | <https://www.postgresql.org/docs/> |
| PostGIS | <https://postgis.net/> |
| TimescaleDB | <https://docs.timescale.com/> |
| pg_cron | <https://github.com/citusdata/pg_cron> |
| pgAdmin | <https://www.pgadmin.org/docs/> |
| GlusterFS | <https://docs.gluster.org/> |

---

### 📝 Wrapping up
This compose file shows one _possible_ way to run a production-grade Saltcorn
stack:

* **Traefik** terminates TLS & multiplexes virtual hosts.
* **Postgres** gains geospatial, time-series & job-scheduler extensions.
* **Backups** are automated, compressed and rotated.
* **pgAdmin** gives click-ops for the database, while GlusterFS replicates data across Swarm nodes.

Use it as a **learning scaffold**, tear it apart and build a setup that slots into _your_ infra.