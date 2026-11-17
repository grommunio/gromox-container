{{/* Database dump script shared by the backup CronJob and the backup-init Job (bash -eo pipefail) */}}
{{- define "grommunio.backupScript" -}}
stamp=$(date +%Y%m%d-%H%M%S)
dir="/backup/${stamp}.partial"
mkdir -p "${dir}"
for comp in CORE CHAT FILES OFFICE ARCHIVE; do
  db_var="GROMMUNIO_${comp}_DB"; user_var="GROMMUNIO_${comp}_USER"; pass_var="GROMMUNIO_${comp}_PASS"
  db="${!db_var}"; user="${!user_var}"
  [ -n "${db}" ] || continue
  echo "dumping ${db}"
  MYSQL_PWD="${!pass_var}" mariadb-dump -h "${DB_HOST}" -P "${DB_PORT}" -u "${user}" \
    --single-transaction --quick --routines --triggers --events "${db}" | gzip > "${dir}/${db}.sql.gz"
  gzip -t "${dir}/${db}.sql.gz"
  if [ "$(stat -c %s "${dir}/${db}.sql.gz")" -lt 200 ]; then
    echo "ERROR: dump of ${db} is empty" >&2; exit 1
  fi
done
mv "${dir}" "/backup/${stamp}"
echo "removing dumps older than ${RETENTION_DAYS} days"
find /backup -mindepth 1 -maxdepth 1 -type d -name '[0-9]*' -mtime +"${RETENTION_DAYS}" -exec rm -rf {} +
du -sh "/backup/${stamp}"
{{- end -}}
