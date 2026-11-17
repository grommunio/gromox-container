# Upgrading

## Routine upgrade

```bash
# with backup.enabled: dump the databases first
kubectl -n grommunio create job --from=cronjob/grommunio-backup pre-upgrade-$(date +%s)

helm upgrade grommunio oci://container.grommunio.com/community/charts/grommunio --version <new> \
  -n grommunio -f my-values.yaml --wait --timeout 25m
```

What happens:

1. `pre-upgrade` hook `db-sync` makes sure the database users exist and carry
   the passwords of the chart Secret (bundled MariaDB, or external database with
   `externalDatabase.manage=true`). It never fails the upgrade on a database
   outage (`dbSync.waitSeconds`).
2. Each StatefulSet replaces its single pod when its template changed (image,
   environment, Secret checksum). Downtime per pod: core 1-3 minutes, archive
   and office about a minute.
3. On start the containers re-apply their configuration from the environment
   (`configure.sh`) and run schema upgrades: gromox (`schema_upgrade=host`),
   Files (`occ upgrade`), MariaDB (`MARIADB_AUTO_UPGRADE`).

Chart versioning: MINOR for new images (`appVersion`), MAJOR for breaking
values changes; breaking changes are listed below.

## Stuck rollouts

A StatefulSet does not replace a pod that is not Ready (for example an image
that cannot be pulled). Fix the values, `helm upgrade`, then delete the broken
pod once:

```bash
kubectl -n grommunio delete pod grommunio-mariadb-0
```

## Rollback

`helm rollback` restores the previous images and configuration. Database
schema changes are one-way: when rolling back across an application version
that changed the schema, restore the databases from the pre-upgrade dump
first (see BACKUP.md).

## Changing storage

StatefulSet `volumeClaimTemplates` are immutable: changing
`persistence.*.size`, `storageClass`, `annotations` or switching to
`existingClaim` on a running release makes `helm upgrade` fail with
"updates to statefulset spec for fields other than ... are forbidden".

* **Grow a volume** (StorageClass with `allowVolumeExpansion`):
  ```bash
  kubectl -n grommunio patch pvc data-grommunio-core-0 -p '{"spec":{"resources":{"requests":{"storage":"100Gi"}}}}'
  ```
  then set the same size in your values and run
  `kubectl -n grommunio delete statefulset grommunio-core --cascade=orphan` followed by
  `helm upgrade` (the pod and the PVC survive; the StatefulSet is re-created with the new template).
* **Change storageClass / move to existingClaim**: same `--cascade=orphan` procedure;
  the data itself has to be copied or restored by you (see BACKUP.md).

## Changing passwords

Set the new values in `secrets.values` (or in your `existingSecret`) and run
`helm upgrade`. `db-sync` updates the database users before the pods restart,
so expect connection errors during the rollout. With `existingSecret` the chart
cannot see the change: bump `secrets.existingSecretVersion` in the same
upgrade (or `kubectl -n grommunio rollout restart statefulset -l app.kubernetes.io/instance=grommunio`).

The grommunio admin password is applied by the core container only when
`maintenance.forceReconfig=true` is set for one upgrade (it re-runs the
one-time initialisation, as in docker-compose). Chat and Files admin passwords
of already created accounts are not changed by the chart. The bundled MariaDB
root password cannot be rotated through the chart; change it with
`ALTER USER` and update the Secret `grommunio-mariadb` by hand.

## Rotating the self-signed certificate

The chart re-issues the server certificate from the stored CA automatically
when `tls.extraDnsNames`/`fqdn` change or when it expires within 30 days
(checked on every `helm upgrade`). To force a new certificate:

```bash
kubectl -n grommunio delete secret grommunio-tls
helm upgrade grommunio ... -f my-values.yaml
```

To rotate the CA as well (clients must re-import `ca.crt`):

```bash
kubectl -n grommunio delete secret grommunio-ca grommunio-tls
helm upgrade grommunio ... -f my-values.yaml
```

## Breaking changes

* **0.2.0**: images come from `container.grommunio.com` by default
  (`global.imageRegistry`), the repository is derived from the new
  `global.edition` (`image.<component>.repository: ""`) and MariaDB from the
  `community/mariadb` image. To keep pulling from another registry, set
  `global.imageRegistry` and the `image.*.repository` values explicitly.
