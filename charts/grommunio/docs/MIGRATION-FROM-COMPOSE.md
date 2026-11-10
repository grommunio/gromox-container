# Migrating from docker-compose

The containers are the same; the data lives in the same paths. Migration is
a copy of the named volumes into the chart's PVCs plus the database dumps.

## 1. Values

Translate `var.env` / `var.local.env`:

| var.env | values.yaml |
|---|---|
| `FQDN`, `DOMAIN`, `TIMEZONE`, `RELAYHOST`, `INDEX_SCHEDULE`, `X500` | `grommunio.*` |
| `ENABLE_CHAT/FILES/OFFICE/ARCHIVE`, `ARCHIVE_*`, `ENABLE_KEYCLOAK`, `KEYCLOAK_*` | `features.*` |
| `ADMIN_PASS`, `*_ADMIN_PASS`, `*_MYSQL_PASS`, `KEYCLOAK_CLIENT_SECRET` | `secrets.values.*` or `secrets.existingSecret` (use the OLD passwords: they are stored in the databases) |
| `*_MYSQL_HOST/USER/DB` | bundled MariaDB (`externalDatabase.<comp>.database/user` for the names) or `externalDatabase.*` |
| `SSL_INSTALL_TYPE=0/2/3`, `SSL_BUNDLE`, `SSL_KEY` | `tls.mode` (`existingSecret` with your current certificate, or `certManager`) |
| `TRUSTED_PROXIES` | `network.trustedProxyCIDRs` |

Also copy the Office JWT secret so existing Files <-> Office links keep working:
`docker exec gromox-office cat /var/lib/grommunio-office/.jwt_secret` -> `secrets.values.OFFICE_JWT_SECRET`.

## 2. Stop the compose stack and dump the databases

```bash
docker compose stop gromox-core gromox-archive gromox-office
for db in gromox-db chat-db files-db office-db archive-db; do
  docker exec $db sh -c 'mariadb-dump --single-transaction -uroot -p"$MARIADB_ROOT_PASSWORD" "$MARIADB_DATABASE"' | gzip > $db.sql.gz
done
```

## 3. Install the chart, then stop the application pods

```bash
helm install grommunio ... -f my-values.yaml --wait --timeout 25m
kubectl -n grommunio scale statefulset grommunio-core grommunio-archive grommunio-office --replicas=0
```

The first start creates the PVCs and empty databases; their content is replaced below.

## 4. Import the databases

```bash
for db in grommunio grochat grofiles groffice groarchive; do
  zcat <dump for $db>.sql.gz | kubectl -n grommunio exec -i grommunio-mariadb-0 -- \
    sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" '"$db"
done
```

## 5. Copy the volumes

Start a helper pod that mounts the target PVC (the core image works) and
stream each docker volume into the matching path:

| compose volume | PVC | path in the helper pod |
|---|---|---|
| `gromox` | `data-grommunio-core-0` | `/` of the PVC (mounted at `/var/lib/gromox`) |
| `gromox_config` | `config-grommunio-core-0` | `etc-gromox/` |
| `grommunio_admin_config` | `config-grommunio-core-0` | `admin-api-config/` |
| `grommunio_admin_license` | `config-grommunio-core-0` | `license/` |
| `grommunio_chat_config` | `config-grommunio-core-0` | `chat-config/` |
| `grommunio_admin_api` | `state-grommunio-core-0` | `admin-api-data/` |
| `grommunio_antispam` | `state-grommunio-core-0` | `antispam/` |
| `grommunio_dav` | `state-grommunio-core-0` | `dav/` |
| `grommunio_web` | `state-grommunio-core-0` | `web/` |
| `grommunio_chat_data` | `state-grommunio-core-0` | `chat-data/` |
| `redis_data` | `state-grommunio-core-0` | `redis/` |
| `postfix_spool` | `state-grommunio-core-0` | `postfix-spool/` |
| `archive_data` | `data-grommunio-archive-0` | `/` (includes `grommunio-archive.key`) |
| `files_data` | `files-grommunio-office-0` | `/` |

Example for one volume:

```bash
kubectl -n grommunio run copy --image=container.grommunio.com/community/gromox-core:<tag> --restart=Never \
  --overrides='{"spec":{"containers":[{"name":"copy","image":"container.grommunio.com/community/gromox-core:<tag>","command":["sleep","3600"],"volumeMounts":[{"name":"v","mountPath":"/target"}]}],"volumes":[{"name":"v","persistentVolumeClaim":{"claimName":"state-grommunio-core-0"}}]}}'
docker run --rm -v grommunio_grommunio_dav:/src:ro alpine tar -C /src -cf - . \
  | kubectl -n grommunio exec -i copy -- sh -c 'rm -rf /target/dav/* && tar -C /target/dav -xf -'
kubectl -n grommunio delete pod copy
```

`tar` preserves ownership (uids are identical in both images). Do not copy
`cert_data`, `gromox_letsencrypt`, `opensuse_data`, `gromox_services`.

## 6. Start

```bash
kubectl -n grommunio scale statefulset grommunio-core grommunio-archive grommunio-office --replicas=1
```

The `.setup` marker files on the config volume skip the one-time
initialisation; `configure.sh` re-applies the Kubernetes specific settings.
Update DNS (A/AAAA/MX) to the new address and run `helm test`.
