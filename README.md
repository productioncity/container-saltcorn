# Saltcorn Containers — Opinionated, Signed & Ready-to-Run
An initiative by [Production&nbsp;City™](https://github.com/productioncity)

[![Build & Publish Saltcorn Containers](https://github.com/productioncity/container-saltcorn/actions/workflows/build-containers.yml/badge.svg?branch=main)](https://github.com/productioncity/container-saltcorn/actions/workflows/build-containers.yml)

---

## 🥑 What is Saltcorn?
[Saltcorn](https://saltcorn.com/) is a brilliant open-source **low-code / no-code platform** that lets anyone build web applications without writing traditional backend code.
Source code lives at <https://github.com/saltcorn/saltcorn>.

> **We are _not_ the Saltcorn project.**
> This repository merely provides an _opinionated_, security-focused container packaging of Saltcorn for the community.

---

## 🏃‍♀️ TL;DR – I Just Want to Run Saltcorn

Below are two ways to spin-up Saltcorn **with the database automatically pre-seeded** using the official sample SQL dump (`docker-entrypoint-initdb.sql`).

1. **Step-by-step (persistent data)** – good for proper local dev.  
2. **One-liner “copy-pasta” demo** – everything is ephemeral; perfect for a quick look.

---

### 1️⃣ Step-by-step (keeps your data)

```bash
# 1. Private bridge so the two containers can talk.
docker network create saltcorn-net

# 2. PostgreSQL with a named volume for durability.
docker run -d \
  --name saltcorn-postgres \
  --network saltcorn-net \
  -v saltcorn-pgdata:/var/lib/postgresql/data \
  -e POSTGRES_DB=saltcorn \
  -e POSTGRES_USER=saltcorn \
  -e POSTGRES_PASSWORD=secretpassword \
  -p 5432:5432 \
  postgres:17-alpine

# 3. Wait until Postgres *and* the “saltcorn” DB are ready, then seed.
docker exec saltcorn-postgres bash -c '
  until psql -U saltcorn -d saltcorn -c "SELECT 1" >/dev/null 2>&1; do
    echo "⏳  Waiting for Postgres to finish initialisation…"
    sleep 2
  done
  echo "✅  Postgres ready – importing sample data"
  curl -sSL https://raw.githubusercontent.com/saltcorn/saltcorn/refs/heads/master/deploy/examples/test/docker-entrypoint-initdb.sql \
  | psql -U saltcorn -d saltcorn
'

# 4. Start Saltcorn and point it at the freshly-seeded DB.
docker run -d \
  --name saltcorn \
  --network saltcorn-net \
  -e PGHOST=saltcorn-postgres \
  -e PGPORT=5432 \
  -e PGDATABASE=saltcorn \
  -e PGUSER=saltcorn \
  -e PGPASSWORD=secretpassword \
  -e SALTCORN_SESSION_SECRET=notsecure \
  -p 3000:3000 \
  ghcr.io/productioncity/saltcorn:latest serve

# 5. Open http://localhost:3000 in your browser and log in (default user: admin@demo.com / password: password).

# 6. Tidy-up when you’re done.
docker stop saltcorn saltcorn-postgres
docker rm   saltcorn saltcorn-postgres
docker volume rm saltcorn-pgdata
docker network rm saltcorn-net
```

---

### 2️⃣ Super-quick demo (everything is **ephemeral** – vanishes on <Ctrl-C>)

```bash
# ⚠️  Nothing persists – demo only.
docker network create saltcorn-net && \
docker run --rm -d \
  --name saltcorn-pg \
  --network saltcorn-net \
  -e POSTGRES_DB=saltcorn \
  -e POSTGRES_USER=saltcorn \
  -e POSTGRES_PASSWORD=secretpassword \
  -p 5432:5432 \
  postgres:17-alpine && \
until docker exec saltcorn-pg psql -U saltcorn -d saltcorn -c "SELECT 1" >/dev/null 2>&1; do
  echo "⏳  Waiting for Postgres…"; sleep 2;
done && \
curl -sSL https://raw.githubusercontent.com/saltcorn/saltcorn/refs/heads/master/deploy/examples/test/docker-entrypoint-initdb.sql \
| docker exec -i saltcorn-pg psql -U saltcorn -d saltcorn && \
docker run --rm -it \
  --name saltcorn \
  --network saltcorn-net \
  -e PGHOST=saltcorn-pg \
  -e PGPORT=5432 \
  -e PGDATABASE=saltcorn \
  -e PGUSER=saltcorn \
  -e PGPASSWORD=secretpassword \
  -e SALTCORN_SESSION_SECRET=notsecure \
  -p 3000:3000 \
  ghcr.io/productioncity/saltcorn:latest serve && \
docker stop saltcorn-pg && \
docker network rm saltcorn-net
```

Press **Ctrl-C** at any time – both containers stop, the network disappears, and your machine is left squeaky clean.

---

## 🏗️ Key Differences to the Official Image

| Aspect                       | Official Saltcorn | `productioncity/saltcorn` (this repo) |
|------------------------------|-------------------|---------------------------------------|
| Base image                   | `node:X`          | **`node:X-slim`** (smaller, safer)    |
| Dependency layout            | Flat `node_modules` | **Nested install-strategy** so plugins work seamlessly |
| Multi-arch builds            | `amd64`           | **`amd64` & `arm64`** (Apple Silicon, Graviton) |
| Image signing                | None              | **Sigstore cosign** key-less signing |
| SBOM / provenance            | None              | **Built-in SBOM** + OCI provenance |
| Tag strategy                 | Partial           | **Full semantic versioning** inc. aliases (`latest`, `edge`, `1.1`, …) |
| Rebuild cadence              | Ad-hoc            | **Weekly & on-push** automated rebuilds |

If these opinions suit you – welcome aboard!

---

## 📦 Supported Architectures

All images are built and pushed for:

* `linux/amd64` (x86-64 servers, traditional cloud builders)
* `linux/arm64` (Apple Silicon, Raspberry Pi 4/5, AWS Graviton, Ampere A1)

Docker/Podman will auto-select the correct variant for your host.

---

## 🧪 Tested Build Matrix
| Node Version | Saltcorn Version | Docker Pull | Build |
|-------------|-----------------|-------------|-------|
| 20-slim | 1.0.0 | `docker pull ghcr.io/productioncity/saltcorn:1.0.0-20-slim` | ✅ |
| 20-slim | 1.4.1 | `docker pull ghcr.io/productioncity/saltcorn:1.4.1-20-slim` | ✅ |
| 20-slim | 1.4.2 | `docker pull ghcr.io/productioncity/saltcorn:1.4.2-20-slim` | ✅ |
| 20-slim | 1.5.0 | `docker pull ghcr.io/productioncity/saltcorn:1.5.0-20-slim` | ✅ |
| 20-slim | 1.6.0-alpha.9 | `docker pull ghcr.io/productioncity/saltcorn:1.6.0-alpha.9-20-slim` | ✅ |
| 22-slim | 1.0.0 | `docker pull ghcr.io/productioncity/saltcorn:1.0.0-22-slim` | ✅ |
| 22-slim | 1.4.1 | `docker pull ghcr.io/productioncity/saltcorn:1.4.1-22-slim` | ✅ |
| 22-slim | 1.4.2 | `docker pull ghcr.io/productioncity/saltcorn:1.4.2-22-slim` | ✅ |
| 22-slim | 1.5.0 | `docker pull ghcr.io/productioncity/saltcorn:1.5.0-22-slim` | ✅ |
| 22-slim | 1.6.0-alpha.9 | `docker pull ghcr.io/productioncity/saltcorn:1.6.0-alpha.9-22-slim` | ✅ |
| 23-slim | 1.0.0 | `docker pull ghcr.io/productioncity/saltcorn:1.0.0-23-slim` | ✅ |
| 23-slim | 1.4.1 | `docker pull ghcr.io/productioncity/saltcorn:1.4.1-23-slim` | ✅ |
| 23-slim | 1.4.2 | `docker pull ghcr.io/productioncity/saltcorn:1.4.2-23-slim` | ✅ |
| 23-slim | 1.5.0 | `docker pull ghcr.io/productioncity/saltcorn:1.5.0-23-slim` | ✅ |
| 23-slim | 1.6.0-alpha.9 | `docker pull ghcr.io/productioncity/saltcorn:1.6.0-alpha.9-23-slim` | ✅ |
| 24-slim | 1.0.0 | `docker pull ghcr.io/productioncity/saltcorn:1.0.0-24-slim` | ✅ |
| 24-slim | 1.4.1 | `docker pull ghcr.io/productioncity/saltcorn:1.4.1-24-slim` | ✅ |
| 24-slim | 1.4.2 | `docker pull ghcr.io/productioncity/saltcorn:1.4.2-24-slim` | ✅ |
| 24-slim | 1.5.0 | `docker pull ghcr.io/productioncity/saltcorn:1.5.0-24-slim` | ✅ |
| 24-slim | 1.6.0-alpha.9 | `docker pull ghcr.io/productioncity/saltcorn:1.6.0-alpha.9-24-slim` | ✅ |
## 📑 Tag Cheat-Sheet

| Tag | Means | Example |
|-----|-------|---------|
| `1.1.4-23-slim` | Explicit Saltcorn _and_ Node base | `docker pull …:1.1.4-23-slim` |
| `1.1.4` | Saltcorn 1.1.4 on **default Node base** | `docker pull …:1.1.4` |
| `1.1`   | Latest `1.1.x` on default Node base | `docker pull …:1.1` |
| `1`     | Latest `1.x`   on default Node base | `docker pull …:1` |
| `latest` | Current stable Saltcorn release | `docker pull …:latest` |
| `edge`   | Bleeding-edge pre-release         | `docker pull …:edge` |

---

## 📦 Container Repositories

We do not publish to the Docker container repository (Docker Hub). That won't change. Please don't submit a PR or feature request to add this.

As soon as Docker stops limiting pulls for open source containers - we can revisit that decision.

---

## 🛠️ Runtime Basics & Environment Tweaks

| Variable | Purpose | Default |
|----------|---------|---------|
| `NODE_ENV`            | Node environment              | `production` |
| `SALTCORN_DISABLE_UPGRADE` | Skip in-app upgrade nags | `true` |
| `PUID` / `PGID`       | Map container user to host UID/GID for file permissions | `1000` |
| `SALTCORN_FILE_STORE` | Put uploaded files somewhere specific | unset = inside container |

PostgreSQL users can set `PGHOST`, `PGPORT`, `PGUSER`, `PGDATABASE`, `PGPASSWORD` and the entry-point will patiently wait for the server to become reachable before starting Saltcorn.

---

## 🤔 Why Another Saltcorn Image?

1. **Slim Base, Faster Deploys** – Built on node-slim
2. **Aggressive Regular Rebuilds** – weekly schedule catches Debian & Node CVEs quickly.
3. **Tamper-evident Supply Chain** – Sigstore signing + BuildKit provenance baked-in.
4. **Multi-arch** – perfect for Apple M-series laptops.

---

## 🔍 Repository Tour

```text
.
├── .ci/build-matrix.yml   # Single source-of-truth for versions
├── .github/workflows/     # Build, sign & publish pipelines
├── containers/            # Production Dockerfile & entry-point
├── scripts/               # Local helper utilities (build, test, etc.)
└── README.md              # You are here
```

*Everything else is plumbing to keep the process reproducible and auditable.*

---

## 🧑‍💻 Hacking on the Containers

### 1. Clone & Prepare

git clone https://github.com/productioncity/container-saltcorn.git
cd container-saltcorn
touch .env                # must exist – even an empty file works
echo "GITHUB_TOKEN=ghp_xxx" >> .env   # optional but enables GitHub API calls

### 2. Coding in VS Code Dev Container

With the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) installed:

1. **Re-open in Container** (from the command palette).
2. The predefined **`.devcontainer/`** spins up a full toolchain: Docker-in-Docker, GitHub CLI, `act`, `yq`, `jq`, etc.

### 3. Local Smoke Tests

# Enumerate (and later build) every image defined in the matrix
make build

# Run the full unit-test suite
make test

# Replay the entire GitHub Actions workflow with “act”
make workflow-build       # quickest – runs the build job only

---

## 🔄 Regenerating the Build Matrix Yourself

The YAML file lists exactly **which** Saltcorn and Node permutations to build.
To add a new Saltcorn version:

1. Edit `.ci/build-matrix.yml` → add your desired version under `saltcorn: versions:`.
2. Commit & push – the CI will build PR images but _not_ publish them.
3. Merge and the main‐branch build will push, sign & verify everything.

Want it more automated? Run:

make matrix       # rewrites .ci/build-matrix.yml in-place

Under the hood this calls `scripts/update_build_matrix.py`, which queries the upstream Saltcorn repo, selects the latest _n_ releases by policy and updates the file.

---

## 🙋‍♀️ Contributing

Pull-requests are warmly welcomed. Please:

1. Create meaningful commits & PR descriptions.
2. English is preferred (but we can use translate if you can't).
3. Make sure `make test` is green.
4. Don’t commit secrets – the `.env` file is intentionally git-ignored.

---

## 📜 Licence

* Container build assets and workflow code: **MIT** (© Troy Kelly, Production City™)
* Saltcorn itself: see upstream licence at <https://github.com/saltcorn/saltcorn/blob/main/LICENSE>

---

## 🙌 Acknowledgements

Huge thanks to the Saltcorn maintainers – they created an amazing platform.
We merely wrap it in what we think is the nicest possible Container parcel.
Enjoy, and happy building!
