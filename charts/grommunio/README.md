# grommunio Helm Chart

Deploys the grommunio groupware stack from this repository (gromox-core,
gromox-archive, gromox-office plus one MariaDB instance per component) to
Kubernetes. Designed to be driven by ArgoCD (see [`../../argocd/`](../../argocd/)),
but works with plain `helm install` too.

> **Warning**: Change **all** default passwords in the values before deploying.
> The defaults exist only so the chart templates out of the box.

## Prerequisites

- Kubernetes 1.25+ and Helm 3.8+
- A default StorageClass (or set `persistence.storageClass`)
- For multi-node clusters: a StorageClass supporting **ReadWriteMany** for the
  shared TLS certificate volume (`persistence.certs`). On single-node clusters
  (k3s, minikube) you can set `persistence.certs.accessModes[0]=ReadWriteOnce`.
- Container images published by this repository's CI to
  `ghcr.io/firlevapz/gromox-container-gromox-{core,archive,office}`.
  If the packages are private, create a pull secret and set `imagePullSecrets`.

## Quick start

```bash
helm install grommunio charts/grommunio \
  --namespace grommunio --create-namespace \
  --set config.fqdn=mail.example.com \
  --set config.domain=example.com \
  --set config.adminPass='S3curePassword!' \
  --set mariadb.rootPassword='AnotherSecret!' \
  --set mariadb.databases.core.password='DbSecret1!' \
  --set mariadb.databases.chat.password='DbSecret2!' \
  --set mariadb.databases.files.password='DbSecret3!' \
  --set mariadb.databases.office.password='DbSecret4!' \
  --set mariadb.databases.archive.password='DbSecret5!'
```

The first start takes several minutes (database schema, TLS certificates,
service configuration). Once the core pod is ready:

| Service | URL |
|---|---|
| Webmail | `https://<FQDN>` |
| Admin UI | `https://<FQDN>:8443` (user `admin`, password `config.adminPass`) |
| ActiveSync | `https://<FQDN>/Microsoft-Server-ActiveSync` |
| CalDAV/CardDAV | `https://<FQDN>/dav` |
| Files | `https://<FQDN>/files` (if enabled) |
| Archive | `https://<FQDN>/archive` (if enabled) |

## Architecture

```
                        ┌────────────────────────────────────────────────┐
 LoadBalancer service   │                Kubernetes cluster              │
 25/80/443/465/587/     │                                                │
 110/143/993/995/8443 ─►│  Deployment gromox-core ──► StatefulSet db-core│
                        │      │  ▲ certs (RWX PVC)                      │
 Ingress (optional,     │      ▼  │                                      │
 web only) ────────────►│  Deployment gromox-archive ► StatefulSet       │
                        │      │                        db-archive       │
                        │      ▼                                         │
                        │  Deployment gromox-office ─► StatefulSets      │
                        │                               db-office,       │
                        │                               db-files,        │
                        │                               db-chat          │
                        └────────────────────────────────────────────────┘
```

- **gromox-core** — mail (postfix, gromox IMAP/POP3/SMTP), webmail, admin UI,
  DAV, ActiveSync, antispam, chat. Exposed through a LoadBalancer service that
  maps the well-known ports to the unprivileged in-container ports (the same
  mapping as `docker-compose.yml`).
- **gromox-archive** — email archiving (ClusterIP only; core proxies
  `/archive` to it and relays mail to its SMTP port 2693).
- **gromox-office** — document server + grommunio Files (ClusterIP only; core
  proxies `/office` and `/files` to it).
- **MariaDB** — one single-replica StatefulSet per enabled component.

Configuration reaches the containers exactly like in docker-compose: a
`var.env` file mounted at `/home/vars/var.env`, rendered from the chart values
into a Secret. To manage `var.env` yourself, set `existingVarEnvSecret` to the
name of a Secret with a `var.env` key.

## How the chart adapts the Docker design to Kubernetes

The containers were built for Docker Compose, where a container's writable
filesystem survives restarts and setup runs once, guarded by marker files. On
Kubernetes every pod starts from a fresh image filesystem, so the chart makes
setup **re-run on every pod start**:

- `FORCE_RECONFIG=true` is set in the rendered `var.env` (value
  `config.forceReconfig`). The setup is designed for a fresh filesystem, so
  re-running it on a fresh pod reproduces the first-boot result.
- `CLEAR_DBS=false` (value `config.clearDbs`) keeps this safe for the core
  database: the init script only populates it when it is empty.
- The archive/office marker directory (`/data`) is an `emptyDir`.

**Consequences you should know about:**

- Mailboxes (`/var/lib/gromox`), the core database, gromox configuration
  including the auto-generated X.500 identifier (`/etc/gromox`), and Let's
  Encrypt state are persisted in PVCs and survive restarts.
- The upstream setup scripts **drop and recreate the chat, files, office and
  archive databases on every setup run** — i.e. on every restart of the pod
  that owns them. Chat history, Files metadata and the archive index are
  therefore *not* durable. This mirrors the behavior of the Docker setup when
  a container is recreated. Treat these features as stateless conveniences,
  not systems of record.
- Self-signed certificates (`ssl.installType=0`) are regenerated on core pod
  restarts. Let's Encrypt certificates (`ssl.installType=2`) are persisted and
  reused while still valid.

## TLS

TLS terminates *inside* the grommunio containers, not at an Ingress:

- `ssl.installType: "0"` — self-signed (default).
- `ssl.installType: "2"` — Let's Encrypt via HTTP-01. Port 80 of the external
  service must be reachable from the internet under `config.fqdn`.

The core pod writes `server-bundle.pem`/`server.key` to the shared certs PVC;
archive and office wait for those files via an init container before starting.

The optional Ingress only covers web traffic (mail protocols need the
LoadBalancer service) and must speak HTTPS to the backend, e.g. with
ingress-nginx:

```yaml
ingress:
  enabled: true
  className: nginx
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
```

## Values

See [`values.yaml`](values.yaml) for the full annotated list. Highlights:

| Key | Description | Default |
|---|---|---|
| `config.fqdn` / `config.domain` | Server FQDN / mail domain | `mail.example.com` / `example.com` |
| `config.adminPass` | grommunio admin password | `changeme-admin` |
| `config.extraVars` | Extra `var.env` entries (map) | `{}` |
| `existingVarEnvSecret` | Bring your own `var.env` Secret | `""` |
| `image.registry`/`image.repository`/`image.tag` | Image location (`<registry>/<repository>-<component>:<tag>`) | `ghcr.io` / `firlevapz/gromox-container` / `latest` |
| `features.chat/files/office/archive.enabled` | Optional components | all `true` |
| `features.keycloak.*` | Keycloak SSO integration | disabled |
| `mariadb.rootPassword`, `mariadb.databases.*` | Database credentials | `changeme-*` |
| `persistence.certs` | Shared TLS cert volume (needs RWX on multi-node) | 128Mi RWX |
| `persistence.coreState` / `persistence.coreMail` | Core config+state / mailboxes | 5Gi / 20Gi |
| `externalService.*` | LoadBalancer for mail + web ports | enabled |
| `externalService.externalTrafficPolicy` | Set `Local` to preserve client IPs for antispam | `""` |
| `ingress.*` | Optional web ingress | disabled |

Set any `externalService.ports.<name>` to `null` to drop that port from the
service.

## Operations

```bash
# Service status inside the core pod
kubectl exec deploy/grommunio-core -- supervisorctl status

# Setup log
kubectl exec deploy/grommunio-core -- cat /var/log/grommunio-setup.log

# Restart a single service
kubectl exec deploy/grommunio-core -- supervisorctl restart nginx
```

PVCs created by this chart carry `helm.sh/resource-policy: keep` and
`argocd.argoproj.io/sync-options: Prune=false`, so neither `helm uninstall`
nor an ArgoCD prune deletes mail data. Remove them explicitly when you really
want to start over.
