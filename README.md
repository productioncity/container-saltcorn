# Saltcorn Container Images – Production-ready, Always Up-to-date  
Maintained by [Production City](https://github.com/productioncity)

---

[![Build & Publish Saltcorn Containers](https://github.com/productioncity/container-saltcorn/actions/workflows/build-containers.yml/badge.svg?branch=main)](https://github.com/productioncity/container-saltcorn/actions/workflows/build-containers.yml)

## 🧪 Tested Build Matrix
| Node Version | Saltcorn Version | Docker Pull | Build |
|-------------|-----------------|-------------|-------|
| 18-slim | 1.0.0 | `docker pull ghcr.io/productioncity/saltcorn:1.0.0-18-slim` | ✅ |
| 18-slim | 1.1.3 | `docker pull ghcr.io/productioncity/saltcorn:1.1.3-18-slim` | ✅ |
| 18-slim | 1.1.4 | `docker pull ghcr.io/productioncity/saltcorn:1.1.4-18-slim` | ✅ |
| 18-slim | 1.2.0-beta.0 | `docker pull ghcr.io/productioncity/saltcorn:1.2.0-beta.0-18-slim` | ✅ |
| 22-slim | 1.0.0 | `docker pull ghcr.io/productioncity/saltcorn:1.0.0-22-slim` | ✅ |
| 22-slim | 1.1.3 | `docker pull ghcr.io/productioncity/saltcorn:1.1.3-22-slim` | ✅ |
| 22-slim | 1.1.4 | `docker pull ghcr.io/productioncity/saltcorn:1.1.4-22-slim` | ✅ |
| 22-slim | 1.2.0-beta.0 | `docker pull ghcr.io/productioncity/saltcorn:1.2.0-beta.0-22-slim` | ✅ |
| 23-slim | 1.0.0 | `docker pull ghcr.io/productioncity/saltcorn:1.0.0-23-slim` | ✅ |
| 23-slim | 1.1.3 | `docker pull ghcr.io/productioncity/saltcorn:1.1.3-23-slim` | ✅ |
| 23-slim | 1.1.4 | `docker pull ghcr.io/productioncity/saltcorn:1.1.4-23-slim` | ✅ |
| 23-slim | 1.2.0-beta.0 | `docker pull ghcr.io/productioncity/saltcorn:1.2.0-beta.0-23-slim` | ✅ |
## 🏃‍♂️ TL;DR — Just Need Saltcorn?

# Pull the latest stable Saltcorn image (Saltcorn 1.1.4 on Node 23-slim)
docker pull ghcr.io/productioncity/saltcorn:latest

# Spin it up (default port 3000):
docker run -p 3000:3000 ghcr.io/productioncity/saltcorn:latest serve

That is all most users will ever need.

## ⚠️ Important

We do not publish to docker hub. The images are freely available in the github container registry, and they don't charge you to pull them - so win win.

---

## 📦 What You Get

* **Battle-tested, minimal images** built from official Node Slim bases.
* **Published exclusively to GitHub Container Registry (GHCR)**:  
  `ghcr.io/productioncity/saltcorn`
* **Full semantic versioning** that encodes both the Saltcorn and Node base
  versions.
* **Automated weekly rebuilds** plus on-push triggers to ensure patches and
  CVE-fixes land quickly.
* **Rich OCI labels** for traceability and SBOM tooling.

---

## 🔖 Supported Tags

| Tag Example | Meaning |
|-------------|---------|
| `1.1.4-23-slim` | Saltcorn 1.1.4 on Node 23-slim |
| `1.1.4` | Saltcorn 1.1.4 on the **default** Node base (currently 23-slim) |
| `1.1` | Latest 1.1 x patch release on default Node base |
| `1` | Latest 1 x minor release on default Node base |
| `latest` | Alias for the default Saltcorn release (1.1.4) on the default Node base |
| `edge` | Alias for the bleeding-edge Saltcorn (1.2.0-beta.0) on the default Node base |

> The exact values are driven by `.ci/build-matrix.yml`; update that file in a
> pull request to alter what is built.

---

## 🎨 Image Labelling

Every image is annotated with the following OCI/Label-Schema metadata:

| Label | Populated With |
|-------|----------------|
| `org.opencontainers.image.title` | `Saltcorn` |
| `org.opencontainers.image.description` | Concise purpose statement |
| `org.opencontainers.image.version` | Full Saltcorn version (e.g. `1.1.4`) |
| `org.opencontainers.image.url` | `https://saltcorn.com/` |
| `org.opencontainers.image.source` | `https://github.com/productioncity/saltcorn-large-language-model` |
| `org.opencontainers.image.licenses` | `MIT` (Saltcorn licence) |
| `org.opencontainers.image.created` | ISO-8601 build timestamp |
| `org.opencontainers.image.authors` | `Troy Kelly <troy@team.production.city>` |
| `org.opencontainers.image.vendor` | `Production City` |
| `org.opencontainers.image.documentation` | GitHub README permalink |
| `org.opencontainers.image.revision` | Git commit SHA used for the build |
| `org.opencontainers.image.ref.name` | Git tag/branch name |
| `org.opencontainers.image.base.name` | e.g. `node:23-slim` |
| `org.label-schema.*` | Duplicate key data for legacy tooling |

Labels are injected by the GitHub Actions workflow at build time; no manual
intervention required.

---

## 🛠️ Repository Layout

.
├── .ci/
│   └── build-matrix.yml     # Single source of truth for version matrix
├── .github/workflows/
│   └── build-containers.yml # CI/CD pipeline
├── containers/
│   └── Dockerfile.saltcorn  # Production Dockerfile
├── scripts/
│   └── build-local.sh       # Local build helper (no push)
├── Makefile                 # `make build` convenience wrapper
└── README.md                # You are here

### Key Design Choices

* **Matrix-driven builds** — A YAML file, not hard-coded workflow, decides what
  gets built. Updates are reviewable and auditable.
* **Node Slim bases** — Small attack surface and faster cold-starts.
* **Nested npm install strategy** — Saltcorn’s plugin loader expects
  per-package `node_modules` layout; we replicate this faithfully.
* **Least-privilege runtime** — Images default to the unprivileged `node`
  user. Environment variables `PUID`/`PGID` allow UID/GID remapping.

---

## 🤓 For Contributors

1. **Fork & clone** the repo.
2. **Edit `.ci/build-matrix.yml`** to add/update Node or Saltcorn versions.
3. **Commit & open a PR**.  
   The CI will run the matrix job but skip pushing images on PRs for safety.
4. **Once merged**, a full build + publish round kicks off automatically.

### Local smoke tests

# Requires Docker/Podman and yq
make build

This enumerates the same matrix the CI would build, printing intended actions.
The actual `docker build` commands will be fleshed out in future sessions.

---

## 🤖 CI/CD Workflow Details

The GitHub Actions pipeline performs three stages:

1. **Matrix generation** (`matrix` job)  
   Reads `.ci/build-matrix.yml` with `yq`, outputs JSON to be consumed by…
2. **Build & Push** (`build` job)  
   For each matrix entry, build the image, tag it according to the rules, push
   to GHCR, and sign it with provenance labels.
3. **Scheduled rebuilds**  
   Runs every Monday 02:00 UTC to pick up upstream base image patches.

All workflow code lives in
`.github/workflows/build-containers.yml` and is intentionally
comment-heavy for maintainability.

---

## 📜 Licence

* Container build scripts and workflow files: **MIT**
* Saltcorn itself: see upstream licence at <https://github.com/saltcorn/saltcorn>

---

## 🙏 Acknowledgements

Saltcorn is an outstanding open-source low-code platform.  
This repository merely provides a predictable container wrapper around it.

Pull requests, issues and suggestions are most welcome.
