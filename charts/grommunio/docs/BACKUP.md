# Backup and restore

## What must be backed up

| Item | Where | Why |
|---|---|---|
| **Archive encryption key** | `/var/lib/grommunio-archive/grommunio-archive.key` on `data-<release>-archive-0` | archived mail is unreadable without it; it is never regenerated |
| Secrets `grommunio-secrets`, `grommunio-mariadb`, `grommunio-ca`, `grommunio-tls` (release name `grommunio`) | Kubernetes | passwords stored in the databases, admin password, Files/Office JWT secret, CA and certificate |
| `config-<release>-core-0` | PVC | admin API JWT signing key, X500 organisation id, license |
| `data-<release>-core-0` | PVC | mailboxes (sqlite + attachments) |
| `state-<release>-core-0` | PVC | DAV sync state, webmail search index, chat uploads, rspamd statistics, postfix queue |
| `data-<release>-archive-0` | PVC | archive store and index |
| `files-<release>-office-0` | PVC | Files user data and configuration |
| `data-<release>-mariadb-0` or logical dumps | PVC / backup PVC | the five databases |

Export the archive key and the Secrets right after the first install. The
`jq` filter strips server-side metadata so the Secrets can be applied elsewhere:

```bash
kubectl -n grommunio exec grommunio-archive-0 -- cat /var/lib/grommunio-archive/grommunio-archive.key > grommunio-archive.key
kubectl -n grommunio get secret -l app.kubernetes.io/instance=grommunio -o json \
  | jq 'del(.items[].metadata.resourceVersion, .items[].metadata.uid, .items[].metadata.creationTimestamp, .items[].metadata.managedFields)' \
  > grommunio-secrets.json
```

## Database dumps (chart CronJob)

```yaml
backup:
  enabled: true
  schedule: "0 2 * * *"
  retentionDays: 14
  persistence: { size: 20Gi }
```

Dumps land in `<stamp>/<database>.sql.gz` on the PVC `<release>-grommunio-backup`
(`helm.sh/resource-policy: keep`). An ad-hoc dump:

```bash
kubectl -n grommunio create job --from=cronjob/grommunio-backup manual-$(date +%s)
```

Copy dumps out with `kubectl cp` from a pod that mounts the PVC, or back the
PVC up with your volume tooling.

## Volumes

Use CSI volume snapshots or Velero (with file-system backup for storage
without snapshots) for the PVCs above. Mailbox sqlite databases are
consistent when the core pod is stopped; for a cold backup:

```bash
kubectl -n grommunio scale statefulset grommunio-core --replicas=0
# snapshot / copy data-grommunio-core-0, state-..., config-...
kubectl -n grommunio scale statefulset grommunio-core --replicas=1
```

A hot snapshot is usually acceptable (sqlite is crash-safe) but may lose the
last seconds of changes.

## Restore into a new cluster

1. Create the namespace and restore the Secrets from the backup **under new
   names** (e.g. `restored-secrets`, `restored-mariadb-root`, `restored-tls`)
   and point the chart at them: `secrets.existingSecret`, `mariadb.existingRootSecret`,
   `tls.mode: existingSecret` + `tls.existingSecret`. Re-creating them under
   the chart's own names requires the Helm ownership annotations and the
   `app.kubernetes.io/managed-by: Helm` label, adjusted to the new
   release/namespace.
2. Create PVCs from the snapshots and point the chart at them:
   ```yaml
   persistence:
     core:
       data:   { existingClaim: restored-core-data }
       state:  { existingClaim: restored-core-state }
       config: { existingClaim: restored-core-config }
     archive:
       data:   { existingClaim: restored-archive-data }
     office:
       files:  { existingClaim: restored-office-files }
   mariadb:
     persistence: { existingClaim: restored-mariadb-data }
   ```
   or, for logical dumps, let the chart create an empty MariaDB and import the
   dumps after the install (`kubectl exec grommunio-mariadb-0 -- mariadb ...`), then
   restart the application pods.
3. If the archive data volume is restored empty but the database is not, provide
   the key through a Secret:
   ```yaml
   features:
     archive:
       encryptionKey:
         existingSecret: grommunio-archive-key   # key grommunio-archive.key
   ```
   The container installs it on a fresh volume and refuses to start when it
   differs from a key already present.
4. `helm install` with the same values; the `.setup` markers on the config
   volume prevent a re-initialisation.
