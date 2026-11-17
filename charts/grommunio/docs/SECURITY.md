# Security model

## Pods

The three application containers (`core`, `archive`, `office`) run
`supervisord` as root; the individual services drop to their own users
(gromox, grommunio, groweb, postfix, nginx workers, redis, groarchive,
grofiles, groffice, ...). The container security context is:

```yaml
runAsUser: 0
allowPrivilegeEscalation: false
seccompProfile: { type: RuntimeDefault }
capabilities:
  drop: [ALL]
  add: [CHOWN, DAC_OVERRIDE, FOWNER, FSETID, SETUID, SETGID, SETPCAP, KILL, AUDIT_WRITE]
```

* `SETUID`/`SETGID`/`SETPCAP`: privilege drop of the services, `su`/`sudo`
  used by the init scripts and cron jobs
* `CHOWN`/`FOWNER`/`FSETID`/`DAC_OVERRIDE`: seeding volumes, fixing
  ownership of persistent data, root processes reading service-owned files
* `KILL`: supervisord signalling programs running as other users
* `AUDIT_WRITE`: PAM (`su`, `sudo`, saslauthd) writes audit records
* `NET_BIND_SERVICE` is not needed: every listener uses a port above 1024
* no host namespaces, no hostPath, no privileged mode

This matches the Pod Security Standards level baseline. Enforce baseline and
warn/audit at restricted:

```bash
kubectl label ns grommunio pod-security.kubernetes.io/enforce=baseline \
  pod-security.kubernetes.io/warn=restricted pod-security.kubernetes.io/audit=restricted
```

MariaDB, the `db-sync`/backup Jobs and the `helm test` pod satisfy
restricted (non-root, read-only root filesystem where possible).

`podSecurity.hostUsers: false` runs the application pods in a user namespace
(Kubernetes >= 1.33, beta on by default; needs a runtime and CSI driver with
idmapped mount support). Root inside the container is then unprivileged on the node.

OpenShift: the application pods need the `anyuid` SCC.

## Secrets

* One Secret with all passwords, generated on first install (`randAlphaNum 32`),
  kept on uninstall; `existingSecret` for externally managed secrets.
* The MariaDB root password is a separate Secret and is mounted only into the
  MariaDB pod and the `db-sync`/backup Jobs; the core pod receives it only when
  `maintenance.clearDbs=true`.
* The containers `unset` every secret variable before starting supervisord,
  so service processes do not carry them in their environment.
* TLS key: Secret mounted `0400`, copied into an emptyDir with the ownership
  the daemons need.
* `NOTES.txt` prints commands to read secrets, never the values.

## Network

* Public listeners: 25 80 443 465 587 143 993 110 995 (+8443 optional).
  The admin UI/rspamd UI are on a ClusterIP Service by default.
* Postfix `mynetworks` is loopback only on the public listeners regardless of
  `externalTrafficPolicy`; kube-proxy SNAT cannot create an open relay.
* Archive and Files relay through a dedicated listener that accepts hosted
  domains only (`permit_auth_destination`). `allowExternalRecipients: true`
  opens it to any destination for Files share notifications and therefore
  requires `networkPolicy.enabled`.
* NetworkPolicies (default on): public ports from `allowedSourceRanges`,
  archive/office reachable only from core, MariaDB only from the release's
  pods, internal relay only from pods labelled `grommunio.io/relay-client`.
  Egress rules are opt-in (`networkPolicy.egress.enabled`).
* Behind an Ingress the core nginx trusts `X-Forwarded-For` only from
  `network.trustedProxyCIDRs`; narrow this list in multi-tenant clusters.

## Supply chain

* Images: `container.grommunio.com/{community,supported}/gromox-{core,archive,office}`,
  built from `gromox-container` on openSUSE Leap 16 with the grommunio
  community or supported (subscription) repositories. Subscription
  credentials are passed to the build as a BuildKit secret and are not part
  of any image layer. Every push is scanned by Trivy in the registry. Pin
  with `image.<c>.digest`.
* Signatures: images, the MariaDB image and the chart are signed with
  cosign; the registry serves only signed images. Verify with
  `cosign verify --key cosign.pub <image>` (key and fingerprint: `docs/REGISTRY.md`
  in the gromox-container repository) or enforce in the cluster with Kyverno
  `verifyImages` / Sigstore policy-controller.
* Supported-edition pull credentials are the customer's grommunio
  subscription credentials, limited to pull and valid while the subscription
  is active. Prefer a self-managed `imagePullSecrets`
  entry over `global.imageCredentials` so the password is not stored in the
  Helm release.
* MariaDB: `container.grommunio.com/community/mariadb`, the official
  `docker.io/library/mariadb` image (pinned minor version) with the current
  Ubuntu security updates and without gosu, rebuilt daily from `mariadb/Dockerfile`.
* Chart: OCI artifact, signed with cosign like the images:
  `cosign verify --key cosign.pub container.grommunio.com/community/charts/grommunio:<version>`.
