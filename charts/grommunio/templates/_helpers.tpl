{{/* vim: set filetype=mustache: */}}

{{- define "grommunio.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "grommunio.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "grommunio.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "grommunio.labels" -}}
helm.sh/chart: {{ include "grommunio.chart" . }}
app.kubernetes.io/name: {{ include "grommunio.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ include "grommunio.imageTag" (dict "root" . "component" "core") | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: grommunio
{{- end -}}

{{/* component labels: include "grommunio.componentLabels" (dict "root" . "component" "core") */}}
{{- define "grommunio.componentLabels" -}}
{{ include "grommunio.labels" .root }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{- define "grommunio.selectorLabels" -}}
app.kubernetes.io/name: {{ include "grommunio.name" .root }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{/* Fully qualified in-cluster Service name */}}
{{- define "grommunio.svcFqdn" -}}
{{- printf "%s.%s.svc.%s" .name .root.Release.Namespace .root.Values.global.clusterDomain -}}
{{- end -}}

{{/* Image tag for a component: image.<c>.tag or appVersion */}}
{{- define "grommunio.imageTag" -}}
{{- $img := index .root.Values.image .component -}}
{{- default .root.Chart.AppVersion $img.tag -}}
{{- end -}}

{{/* Image reference: include "grommunio.image" (dict "root" . "component" "core") */}}
{{- define "grommunio.image" -}}
{{- $img := index .root.Values.image .component -}}
{{- $registry := default .root.Values.global.imageRegistry $img.registry -}}
{{- $repo := $img.repository -}}
{{- if not $repo -}}
{{- $repo = printf "%s/gromox-%s" .root.Values.global.edition .component -}}
{{- end -}}
{{- $ref := ternary $repo (printf "%s/%s" $registry $repo) (empty $registry) -}}
{{- if $img.digest -}}
{{- printf "%s@%s" $ref $img.digest -}}
{{- else -}}
{{- printf "%s:%s" $ref (include "grommunio.imageTag" .) -}}
{{- end -}}
{{- end -}}

{{/* Name of the chart-managed registry Secret ("" when not created) */}}
{{- define "grommunio.registrySecretName" -}}
{{- if .Values.global.imageCredentials.username -}}
{{- printf "%s-registry" (include "grommunio.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* imagePullSecrets entries from global.imagePullSecrets (strings or {name: ...}) */}}
{{- define "grommunio.userPullSecrets" -}}
{{- $list := list -}}
{{- range .Values.global.imagePullSecrets -}}
{{- $list = append $list (ternary (dict "name" .) . (kindIs "string" .)) -}}
{{- end -}}
{{- toJson $list -}}
{{- end -}}

{{/* imagePullSecrets block for a pod spec (global list + chart-managed Secret) */}}
{{- define "grommunio.imagePullSecrets" -}}
{{- $list := include "grommunio.userPullSecrets" . | fromJsonArray -}}
{{- with include "grommunio.registrySecretName" . -}}
{{- $list = append $list (dict "name" .) -}}
{{- end -}}
{{- with $list -}}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end -}}
{{- end -}}

{{/*
imagePullSecrets for pre-install hooks: the chart-managed registry Secret is a
regular release object and does not exist yet when pre-install hooks run, so
hooks only use global.imagePullSecrets (they run the public MariaDB image).
*/}}
{{- define "grommunio.hookImagePullSecrets" -}}
{{- with include "grommunio.userPullSecrets" . | fromJsonArray -}}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end -}}
{{- end -}}

{{- define "grommunio.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "grommunio.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "grommunio.secretName" -}}
{{- default (printf "%s-secrets" (include "grommunio.fullname" .)) .Values.secrets.existingSecret -}}
{{- end -}}

{{- define "grommunio.rootSecretName" -}}
{{- if .Values.mariadb.enabled -}}
{{- default (printf "%s-mariadb" (include "grommunio.fullname" .)) .Values.mariadb.existingRootSecret -}}
{{- else -}}
{{- .Values.externalDatabase.adminSecret -}}
{{- end -}}
{{- end -}}

{{- define "grommunio.tlsSecretName" -}}
{{- if eq .Values.tls.mode "existingSecret" -}}
{{- required "tls.existingSecret is required with tls.mode=existingSecret" .Values.tls.existingSecret -}}
{{- else -}}
{{- default (printf "%s-tls" (include "grommunio.fullname" .)) .Values.tls.secretName -}}
{{- end -}}
{{- end -}}

{{- define "grommunio.caSecretName" -}}
{{- printf "%s-ca" (include "grommunio.fullname" .) -}}
{{- end -}}

{{/*
Application secret values as a JSON object, memoized per render.
Precedence per key: secrets.values.<KEY> > Secret already in the cluster > random.
With secrets.existingSecret nothing is generated (the pods read that Secret)
and the map holds only secrets.values.
*/}}
{{- define "grommunio.secretKeys" -}}
ADMIN_PASS CHAT_ADMIN_PASS FILES_ADMIN_PASS ARCHIVE_ADMIN_PASS ARCHIVE_AUDIT_PASS MYSQL_PASS CHAT_MYSQL_PASS FILES_MYSQL_PASS OFFICE_MYSQL_PASS ARCHIVE_MYSQL_PASS OFFICE_JWT_SECRET
{{- end -}}

{{- define "grommunio.secrets" -}}
{{- if not (hasKey .Values "__secrets") -}}
  {{- $data := dict -}}
  {{- $existing := dict -}}
  {{- if not .Values.secrets.existingSecret -}}
    {{- $found := lookup "v1" "Secret" .Release.Namespace (include "grommunio.secretName" .) -}}
    {{- if $found -}}{{- $existing = default (dict) $found.data -}}{{- end -}}
  {{- end -}}
  {{- range $k := splitList " " (include "grommunio.secretKeys" .) -}}
    {{- $v := "" -}}
    {{- if hasKey $.Values.secrets.values $k -}}
      {{- $v = index $.Values.secrets.values $k | toString -}}
    {{- else if hasKey $existing $k -}}
      {{- $v = index $existing $k | b64dec -}}
    {{- else if $.Values.secrets.existingSecret -}}
      {{- $v = "" -}}
    {{- else if $.Values.secrets.autoGenerate -}}
      {{- $v = randAlphaNum (ternary 48 32 (eq $k "OFFICE_JWT_SECRET") | int) -}}
    {{- else -}}
      {{- fail (printf "secrets.values.%s must be set when secrets.autoGenerate=false and no existingSecret is used" $k) -}}
    {{- end -}}
    {{- $_ := set $data $k $v -}}
  {{- end -}}
  {{- /* not auto-generated */ -}}
  {{- $kc := "" -}}
  {{- if hasKey .Values.secrets.values "KEYCLOAK_CLIENT_SECRET" -}}
    {{- $kc = index .Values.secrets.values "KEYCLOAK_CLIENT_SECRET" | toString -}}
  {{- else if hasKey $existing "KEYCLOAK_CLIENT_SECRET" -}}
    {{- $kc = index $existing "KEYCLOAK_CLIENT_SECRET" | b64dec -}}
  {{- end -}}
  {{- $_ := set $data "KEYCLOAK_CLIENT_SECRET" $kc -}}
  {{- $_ := set .Values "__secrets" $data -}}
{{- end -}}
{{- .Values.__secrets | toJson -}}
{{- end -}}

{{/* MariaDB root password (bundled database), memoized */}}
{{- define "grommunio.rootPassword" -}}
{{- if not (hasKey .Values "__rootpw") -}}
  {{- $v := "" -}}
  {{- if hasKey .Values.secrets.values "MYSQL_ROOT_PASS" -}}
    {{- $v = index .Values.secrets.values "MYSQL_ROOT_PASS" | toString -}}
  {{- else -}}
    {{- $found := lookup "v1" "Secret" .Release.Namespace (include "grommunio.rootSecretName" .) -}}
    {{- if and $found (hasKey (default (dict) $found.data) "MYSQL_ROOT_PASS") -}}
      {{- $v = index $found.data "MYSQL_ROOT_PASS" | b64dec -}}
    {{- else -}}
      {{- $v = randAlphaNum 32 -}}
    {{- end -}}
  {{- end -}}
  {{- $_ := set .Values "__rootpw" $v -}}
{{- end -}}
{{- .Values.__rootpw -}}
{{- end -}}

{{- define "grommunio.dbHost" -}}
{{- if .Values.mariadb.enabled -}}
{{- include "grommunio.svcFqdn" (dict "root" . "name" (printf "%s-mariadb" (include "grommunio.fullname" .))) -}}
{{- else -}}
{{- required "externalDatabase.host is required when mariadb.enabled=false" .Values.externalDatabase.host -}}
{{- end -}}
{{- end -}}

{{- define "grommunio.dbPort" -}}
{{- if .Values.mariadb.enabled -}}3306{{- else -}}{{ .Values.externalDatabase.port }}{{- end -}}
{{- end -}}

{{/* "true" when the office pod (Files and/or Office) is deployed */}}
{{- define "grommunio.officePodEnabled" -}}
{{- if or .Values.features.files.enabled .Values.features.office.enabled -}}true{{- end -}}
{{- end -}}

{{/* Certificate DNS names (JSON list) */}}
{{- define "grommunio.dnsNames" -}}
{{- $names := list .Values.grommunio.fqdn (printf "autodiscover.%s" .Values.grommunio.domain) -}}
{{- $names = concat $names .Values.tls.extraDnsNames -}}
{{- $names | uniq | toJson -}}
{{- end -}}

{{/*
Self-signed CA and server certificate as JSON, memoized. The CA is reused from
the cluster, the leaf only under the conditions below.
Keys: cacrt cakey crt key sanhash caserial crthash notafter
*/}}
{{- define "grommunio.selfSignedTls" -}}
{{- if not (hasKey .Values "__tls") -}}
  {{- $names := include "grommunio.dnsNames" . | fromJsonArray -}}
  {{- $sanhash := $names | join "," | sha256sum | trunc 16 -}}
  {{- $days := int .Values.tls.selfSigned.validityDays -}}
  {{- $cn := default (printf "grommunio CA (%s)" .Values.grommunio.fqdn) .Values.tls.selfSigned.caCommonName -}}
  {{- $cacrt := "" -}}{{- $cakey := "" -}}
  {{- $existingCa := lookup "v1" "Secret" .Release.Namespace (include "grommunio.caSecretName" .) -}}
  {{- if and $existingCa (hasKey (default (dict) $existingCa.data) "tls.crt") (hasKey $existingCa.data "tls.key") -}}
    {{- $cacrt = index $existingCa.data "tls.crt" | b64dec -}}
    {{- $cakey = index $existingCa.data "tls.key" | b64dec -}}
  {{- else -}}
    {{- $ca := genCA $cn $days -}}
    {{- $cacrt = $ca.Cert -}}{{- $cakey = $ca.Key -}}
  {{- end -}}
  {{- $crt := "" -}}{{- $key := "" -}}
  {{- $existing := lookup "v1" "Secret" .Release.Namespace (include "grommunio.tlsSecretName" .) -}}
  {{- $notAfter := "" -}}
  {{- $ann := dict -}}
  {{- if $existing -}}{{- $ann = default (dict) $existing.metadata.annotations -}}{{- end -}}
  {{- /* reuse the stored leaf only if this chart issued it for the same SANs and
         CA and it does not expire within 30 days */ -}}
  {{- $reuse := false -}}
  {{- if and $existing (hasKey (default (dict) $existing.data) "tls.crt") -}}
    {{- $storedCrt := index $existing.data "tls.crt" | b64dec -}}
    {{- $renewAt := now | dateModify "720h" | unixEpoch -}}
    {{- $expiry := 0 -}}
    {{- with (index $ann "grommunio.io/not-after" | default "") -}}{{- $expiry = toDate "2006-01-02T15:04:05Z" . | unixEpoch -}}{{- end -}}
    {{- if and (eq (index $ann "grommunio.io/san-hash" | default "") $sanhash)
               (eq (index $ann "grommunio.io/ca-serial" | default "") ($cacrt | sha256sum | trunc 16))
               (eq (index $ann "grommunio.io/crt-hash" | default "") ($storedCrt | sha256sum | trunc 16))
               (gt (int $expiry) (int $renewAt)) -}}
      {{- $reuse = true -}}
      {{- $crt = $storedCrt -}}
      {{- $key = index $existing.data "tls.key" | b64dec -}}
      {{- $notAfter = index $ann "grommunio.io/not-after" -}}
    {{- end -}}
  {{- end -}}
  {{- if not $reuse -}}
    {{- $ca := buildCustomCert ($cacrt | b64enc) ($cakey | b64enc) -}}
    {{- $cert := genSignedCert .Values.grommunio.fqdn nil $names $days $ca -}}
    {{- $crt = printf "%s%s" $cert.Cert $cacrt -}}
    {{- $key = $cert.Key -}}
    {{- $notAfter = now | dateModify (printf "%dh" (mul $days 24)) | date "2006-01-02T15:04:05Z" -}}
  {{- end -}}
  {{- $_ := set .Values "__tls" (dict "cacrt" $cacrt "cakey" $cakey "crt" $crt "key" $key "sanhash" $sanhash "caserial" ($cacrt | sha256sum | trunc 16) "crthash" ($crt | sha256sum | trunc 16) "notafter" $notAfter) -}}
{{- end -}}
{{- .Values.__tls | toJson -}}
{{- end -}}

{{/* Security context of the application containers */}}
{{- define "grommunio.appSecurityContext" -}}
runAsUser: 0
runAsGroup: 0
runAsNonRoot: false
privileged: false
allowPrivilegeEscalation: {{ .Values.podSecurity.allowPrivilegeEscalation }}
readOnlyRootFilesystem: false
seccompProfile:
  {{- toYaml .Values.podSecurity.seccompProfile | nindent 2 }}
capabilities:
  drop: ["ALL"]
  add:
    {{- toYaml .Values.podSecurity.capabilities.add | nindent 4 }}
{{- end -}}

{{/* Restricted security context for helper pods (mariadb, jobs, tests) */}}
{{- define "grommunio.restrictedSecurityContext" -}}
runAsNonRoot: true
runAsUser: {{ .uid }}
runAsGroup: {{ .uid }}
allowPrivilegeEscalation: false
privileged: false
readOnlyRootFilesystem: {{ default false .readOnly }}
seccompProfile:
  type: RuntimeDefault
capabilities:
  drop: ["ALL"]
{{- end -}}

{{/* Probe block: include "grommunio.probes" (dict "root" . "component" "core") */}}
{{- define "grommunio.probes" -}}
{{- $p := (index .root.Values .component).probes -}}
startupProbe:
  exec:
    command: ["/home/healthcheck.sh", "--essential"]
  periodSeconds: {{ $p.startup.periodSeconds }}
  failureThreshold: {{ $p.startup.failureThreshold }}
  timeoutSeconds: {{ $p.startup.timeoutSeconds }}
livenessProbe:
  exec:
    command: ["/home/healthcheck.sh", "--essential"]
  periodSeconds: {{ $p.liveness.periodSeconds }}
  failureThreshold: {{ $p.liveness.failureThreshold }}
  timeoutSeconds: {{ $p.liveness.timeoutSeconds }}
readinessProbe:
  exec:
    command: ["/home/healthcheck.sh", "--essential"]
  periodSeconds: {{ $p.readiness.periodSeconds }}
  failureThreshold: {{ $p.readiness.failureThreshold }}
  timeoutSeconds: {{ $p.readiness.timeoutSeconds }}
{{- end -}}

{{/* Common pod spec bits: include "grommunio.podCommon" (dict "root" . "component" "core") */}}
{{- define "grommunio.podCommon" -}}
{{- $c := index .root.Values .component -}}
serviceAccountName: {{ include "grommunio.serviceAccountName" .root }}
automountServiceAccountToken: false
enableServiceLinks: false
terminationGracePeriodSeconds: {{ $c.terminationGracePeriodSeconds }}
{{- if not .root.Values.podSecurity.hostUsers }}
hostUsers: false
{{- end }}
{{- with include "grommunio.imagePullSecrets" .root }}
{{ . }}
{{- end }}
{{- with $c.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $c.tolerations }}
tolerations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $c.affinity }}
affinity:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $c.priorityClassName }}
priorityClassName: {{ . }}
{{- end }}
{{- end -}}

{{/* hostAliases for archive/office (hairpin to the FQDN through the internal Service) */}}
{{- define "grommunio.hostAliases" -}}
{{- if and (eq .Values.network.hairpin.mode "hostAliases") .Values.service.internal.clusterIP }}
hostAliases:
  - ip: {{ .Values.service.internal.clusterIP | quote }}
    hostnames:
      - {{ .Values.grommunio.fqdn }}
      - autodiscover.{{ .Values.grommunio.domain }}
{{- end }}
{{- end -}}

{{/* Checksum annotations shared by the three app pods */}}
{{- define "grommunio.checksumAnnotations" -}}
checksum/env: {{ include (print .Template.BasePath "/configmap-env.yaml") . | sha256sum }}
{{- if not .Values.secrets.existingSecret }}
checksum/secrets: {{ include "grommunio.secrets" . | sha256sum }}
{{- else if .Values.secrets.existingSecretVersion }}
checksum/secrets: {{ .Values.secrets.existingSecretVersion | toString | sha256sum }}
{{- end }}
{{- if and .Values.tls.rolloutOnChange (eq .Values.tls.mode "selfSigned") }}
checksum/tls: {{ (include "grommunio.selfSignedTls" . | fromJson).crt | sha256sum }}
{{- end }}
{{- end -}}

{{/* Validation of values that cannot be expressed in the schema */}}
{{- define "grommunio.validate" -}}
{{- if not .Values.grommunio.fqdn }}{{ fail "grommunio.fqdn is required" }}{{ end -}}
{{- if not .Values.grommunio.domain }}{{ fail "grommunio.domain is required" }}{{ end -}}
{{- if and (eq .Values.global.edition "supported") (eq .Values.global.imageRegistry "container.grommunio.com") (not .Values.global.imageCredentials.username) (not .Values.global.imagePullSecrets) }}{{ fail "global.edition=supported pulls from the subscription project of container.grommunio.com: set global.imageCredentials.username/password (your grommunio subscription credentials) or global.imagePullSecrets" }}{{ end -}}
{{- if and .Values.global.imageCredentials.username (not .Values.global.imageCredentials.password) }}{{ fail "global.imageCredentials.password is required with global.imageCredentials.username" }}{{ end -}}
{{- if and (eq .Values.tls.mode "certManager") (not .Values.tls.certManager.issuerRef.name) }}{{ fail "tls.certManager.issuerRef.name is required with tls.mode=certManager" }}{{ end -}}
{{- if and .Values.network.internalRelay.allowExternalRecipients (not .Values.networkPolicy.enabled) }}{{ fail "network.internalRelay.allowExternalRecipients=true requires networkPolicy.enabled=true (the internal relay would otherwise be reachable by every pod in the cluster)" }}{{ end -}}
{{- if and (not .Values.mariadb.enabled) .Values.externalDatabase.manage (not .Values.externalDatabase.adminSecret) }}{{ fail "externalDatabase.adminSecret is required with externalDatabase.manage=true" }}{{ end -}}
{{- if and .Values.maintenance.clearDbs (not (include "grommunio.rootSecretName" .)) }}{{ fail "maintenance.clearDbs needs a database root secret" }}{{ end -}}
{{- if and .Values.ingress.admin.enabled (not .Values.ingress.admin.host) }}{{ fail "ingress.admin.host is required with ingress.admin.enabled" }}{{ end -}}
{{- if and .Values.ingress.enabled (not .Values.ingress.realIpFrom) }}{{ fail "ingress.realIpFrom (CIDRs of the ingress controller pods/nodes whose X-Forwarded-For is trusted) is required with ingress.enabled" }}{{ end -}}
{{- if and .Values.ingress.enabled .Values.networkPolicy.enabled (not .Values.networkPolicy.ingressController.namespaceSelector) (not .Values.networkPolicy.ingressController.podSelector) }}{{ fail "networkPolicy.ingressController.namespaceSelector and/or podSelector must select the ingress controller when ingress.enabled and networkPolicy.enabled (otherwise every pod in the cluster could bypass the controller)" }}{{ end -}}
{{- end -}}
