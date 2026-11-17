# grommunio Helm chart

Deploys [grommunio](https://grommunio.com/) on Kubernetes from the
[gromox-container](https://github.com/grommunio/gromox-container) images:

| Pod | Image | Contents |
|---|---|---|
| `<release>-core-0` | `gromox-core` | nginx, postfix, gromox (MAPI/HTTP, IMAP, POP3, delivery, midb, zcore, event), admin API/UI, webmail, EAS, CalDAV/CardDAV, rspamd, redis, saslauthd, cron, optional chat |
| `<release>-archive-0` | `gromox-archive` | mail archive (piler), sphinx full-text search, web UI |
| `<release>-office-0` | `gromox-office` | grommunio Files (Nextcloud) and Office (document server), rabbitmq, redis |
| `<release>-mariadb-0` | `library/mariadb` | one bundled MariaDB holding the five databases (optional: external database) |

Everything that `var.env` configures in docker-compose is configured through
`values.yaml`. The images are the same; a handful of environment variables
switch them into Kubernetes mode (see `docs/kubernetes.md` in the image
repository).

## Requirements

* Kubernetes >= 1.28, Helm >= 3.12
* a StorageClass providing `ReadWriteOnce` volumes (no RWX needed)
* a way to publish one IP for the mail and web ports: a LoadBalancer
  implementation (cloud, MetalLB, kube-vip), or a node address used as
  `externalIPs`
* resources: about 2 CPU / 7 GiB requests with all features on
  (see `core.resources`, `office.resources`, `archive.resources`, `mariadb.resources`)
* optional: cert-manager for publicly trusted certificates, an Ingress controller for HTTP(S)

## Quick start

```bash
cat > my-values.yaml <<'EOF'
grommunio:
  fqdn: mail.example.com
  domain: example.com
EOF

helm install grommunio oci://container.grommunio.com/community/charts/grommunio \
  --namespace grommunio --create-namespace \
  -f my-values.yaml --wait --timeout 25m
```

or from this repository: `helm install grommunio charts/grommunio -n grommunio --create-namespace -f my-values.yaml`.

This installs the community edition. Subscription customers add their pull
credentials and select the supported edition (see Images and editions).

The first start takes several minutes (database initialisation, Files
installation); no first-boot step runs as a `post-*` hook, so `--wait` is
safe to use. The release notes show the address for DNS, how to read the admin
password and how to export the archive encryption key. Run
`helm test grommunio -n grommunio` to check the deployment.

Point the following records at the published IP:

```
mail.example.com.          A/AAAA  <ip>
autodiscover.example.com.  A/AAAA  <ip>
example.com.               MX 10   mail.example.com.
```

Then log in to the admin UI as `admin` (password: Secret `grommunio-secrets`, key `ADMIN_PASS`),
create the domain and users.

Object names: every object is prefixed with the release name (`grommunio-core-0`,
`grommunio-secrets`, ...). When the release name does not contain "grommunio",
the prefix is `<release>-grommunio`. The commands below use the quick-start
release name; `helm get notes grommunio` prints the exact names.

## Images and editions

All images come from `container.grommunio.com`:

| Path | Access | Content |
|---|---|---|
| `community/gromox-{core,archive,office}` | public, no login | built from the community packages |
| `supported/gromox-{core,archive,office}` | subscription customers | built from the supported packages |
| `community/mariadb` | public | mirror of `docker.io/library/mariadb:11.8`, refreshed daily |
| `community/charts/grommunio` | public | this chart (OCI) |

Tags: `<appVersion>` (for example `2026.11`) moves to the newest build of
that release; `<appVersion>-<YYYYMMDDhhmm>` names one build. The registry
keeps the last 14 builds of each image. Pin a digest
(`image.<component>.digest`) for reproducible deployments, and keep a copy in
your own registry if you need a build for longer.

Supported edition, with the robot account you received from grommunio:

```yaml
global:
  edition: supported
  imageCredentials:
    username: robot$supported+customer-1234
    password: "<secret>"
```

The chart then creates the pull Secret `<release>-registry` and uses it in
every pod. To keep the password out of the values, create the Secret yourself
and reference it instead:

```bash
kubectl -n grommunio create secret docker-registry grommunio-registry \
  --docker-server=container.grommunio.com \
  --docker-username='robot$supported+customer-1234' --docker-password='<secret>'
```

```yaml
global:
  edition: supported
  imagePullSecrets: [grommunio-registry]
```

All images and the chart are signed with cosign; verify them with the
public key `cosign.pub` of the gromox-container repository:

```bash
cosign verify --key cosign.pub container.grommunio.com/community/gromox-core:2026.11
```

Switching an existing installation between editions is a normal
`helm upgrade`: the data format is the same. For air-gapped clusters mirror
the images (`skopeo copy --all`) and set `global.imageRegistry`.

## Exposure

The chart renders three Services for the core pod:

| Service | Purpose | Default |
|---|---|---|
| `<release>-core` | public: 25 80 443 465 587 143 993 110 995 (+ 8443 when `service.core.ports.admin.enabled`) | `LoadBalancer`, `externalTrafficPolicy: Local` |
| `<release>-core-admin` | admin UI and rspamd UI (port 8443) | `ClusterIP` (use `kubectl port-forward`, `service.admin.type`, or `ingress.admin`) |
| `<release>-core-internal` | used by archive/office: internal SMTP relay, HTTPS hairpin; Ingress backend | `ClusterIP` |

`externalTrafficPolicy: Local` keeps the client IP for postfix, rspamd and the
logs; with a single endpoint there is no imbalance. Set it to `Cluster` for
load balancers that cannot health-check nodes.

### Bare metal / k3s without a load balancer

```yaml
service:
  core:
    type: ClusterIP
    externalIPs: [203.0.113.10]      # an address that reaches a node
    externalTrafficPolicy: Local
```

kube-proxy answers for the external IP on the node that has the pod; `--wait`
does not block (a `LoadBalancer` Service without a controller never becomes ready).

### Ingress for HTTP(S)

```yaml
ingress:
  enabled: true
  className: nginx
  controller: nginx          # nginx | traefik | haproxy | none (re-encrypt annotations)
tls:
  mode: certManager
  certManager:
    issuerRef: { name: letsencrypt, kind: ClusterIssuer }
```

When the Ingress is enabled, ports 80/443 are removed from the public Service
(mail ports stay there) and the core nginx trusts `X-Forwarded-For` from
`ingress.realIpFrom` (required: the addresses of your ingress controller).
With `networkPolicy.enabled` you must also select the controller in
`networkPolicy.ingressController` so that only it can reach the HTTPS backend.
The Ingress backend is HTTPS (the core nginx terminates TLS with the same
certificate). Do not put cert-manager annotations on the Ingress: the
certificate is managed by the chart's Certificate object.

## TLS

The certificate always lives in one `kubernetes.io/tls` Secret that is
mounted into all three pods. Rotations are picked up inside the containers
within about a minute without a restart (`cert-watch`).

| `tls.mode` | Source |
|---|---|
| `selfSigned` (default) | the chart generates a CA and a certificate for `fqdn` and `autodiscover.<domain>`; both Secrets are kept across upgrades and uninstall, the certificate is re-issued from the CA when its SANs change or it is within 30 days of expiry. Install `ca.crt` of Secret `grommunio-ca` on clients. Not for GitOps renderers (see Secrets). |
| `certManager` | the chart renders a `Certificate`; HTTP-01 needs `ingress.enabled`, DNS-01 works without Ingress. A private CA issuer's `ca.crt` is trusted inside the pods automatically. |
| `existingSecret` | any Secret you manage (`tls.crt` full chain, `tls.key`, optional `ca.crt`). |

Let's Encrypt via certbot inside the container (`SSL_INSTALL_TYPE=2` of
docker-compose) is not available on Kubernetes; use cert-manager.

## Database

By default one MariaDB (`container.grommunio.com/community/mariadb:11.8`, a mirror of the official image) is deployed with
the five databases `grommunio`, `grochat`, `grofiles`, `groffice`,
`groarchive`, created by an init script on first start. A `pre-upgrade` Job
(`dbSync`) keeps the users' passwords in step with the chart Secret.

External database:

```yaml
mariadb:
  enabled: false
externalDatabase:
  host: mariadb.example.internal
  port: 3306
  manage: true                 # create databases/users with the admin credentials below
  adminSecret: my-db-root      # key MYSQL_ROOT_PASS
  adminUser: root
  core:    { database: grommunio,  user: grommunio }
  chat:    { database: grochat,    user: grochat }
  files:   { database: grofiles,   user: grofiles }
  office:  { database: groffice,   user: groffice }
  archive: { database: groarchive, user: groarchive }
```

With `manage: false` create the databases and users yourself (passwords from
the chart Secret). MariaDB 10.6 or newer, `utf8mb4`.

## Secrets

All passwords are in one Secret (`grommunio-secrets`), generated on first
install and kept (`helm.sh/resource-policy: keep`). Each container receives
only the keys it needs. Provide your own:

```yaml
secrets:
  existingSecret: my-grommunio-secrets    # keys: see values.yaml
# or
secrets:
  values:
    ADMIN_PASS: "..."
```

`helm template` and GitOps tools (ArgoCD, Flux) cannot look up objects in the
cluster: use `existingSecret` (or `secrets.values`) and `tls.mode:
certManager` or `existingSecret` there, otherwise every render generates new
passwords and a new CA. After changing passwords inside an `existingSecret`,
bump `secrets.existingSecretVersion` so the pods restart with the new values.

## Storage

| PVC | Pod | Content | Default |
|---|---|---|---|
| `data-<release>-core-0` | core | mailboxes (`/var/lib/gromox`) | 50Gi |
| `state-<release>-core-0` | core | admin API, antispam, DAV, webmail sessions/index, chat uploads, redis, postfix spool | 20Gi |
| `config-<release>-core-0` | core | `/etc/gromox`, admin API JWT key, license, chat config | 1Gi |
| `data-<release>-archive-0` | archive | archived mail, search index, **encryption key** | 100Gi |
| `files-<release>-office-0` | office | Files configuration and user data | 50Gi |
| `data-<release>-mariadb-0` | mariadb | databases | 20Gi |

`persistence.<pod>.<volume>.existingClaim` mounts an existing PVC instead
(restores, migration). All StatefulSets retain their PVCs on delete.

## Mail relay and network policy

Postfix trusts only loopback on the public ports; nothing in the cluster can
relay without authentication. Archive and Files relay through a dedicated
listener (`network.internalRelay.port`) that accepts mail for hosted domains
only. `network.internalRelay.allowExternalRecipients: true` lets Files send
share notifications to external recipients and requires
`networkPolicy.enabled` (default on). The NetworkPolicies allow the public
ports from `networkPolicy.core.allowedSourceRanges`, archive/office only from
core, and MariaDB only from the release's pods.

## Operations

* **Upgrade**: `helm upgrade grommunio ... --wait`. Each StatefulSet replaces
  its single pod (a few minutes of downtime); schema upgrades are applied by
  the applications. See `docs/UPGRADING.md`.
* **Backups**: `backup.enabled: true` dumps the databases to a PVC on a
  schedule (and once after every install/upgrade); volume snapshots or Velero
  for the data volumes. See `docs/BACKUP.md`.
* **Storage changes**: PVC sizes and classes are fixed at creation
  (StatefulSet volumeClaimTemplates are immutable); see `docs/UPGRADING.md`.
* **Migration from docker-compose**: `docs/MIGRATION-FROM-COMPOSE.md`.
* **Security model** (root containers, capabilities, PSA level): `docs/SECURITY.md`.
* **Logs**: every supervised program logs to the pod's stdout (`kubectl logs`).
* **Inside a pod**: `kubectl exec -n grommunio <release>-core-0 -- supervisorctl status`,
  `grommunio-admin ...`, `postqueue -p`, as in docker-compose.

## Values

All options are documented in `values.yaml`. Examples in `examples/`:

* `values-k3s-externalip.yaml`: bare metal with a node address
* `values-ingress-certmanager.yaml`: Ingress + Let's Encrypt via cert-manager
* `values-external-db.yaml`: external MariaDB
* `values-core-only.yaml`: mail/groupware only, no chat/files/office/archive
* `values-supported.yaml`: supported edition with subscription pull credentials

## Limitations

* One replica per component (gromox keeps mailboxes in sqlite files). A
  restart or node drain means minutes of downtime; active/passive failover
  relies on the storage (RWO network volume) and node shutdown handling.
* The application containers run as root with a reduced capability set
  (Pod Security "baseline"); MariaDB and the helper Jobs are "restricted".
* No PROXY protocol, no TLS to the database, no IPv6-only clusters in this version.
