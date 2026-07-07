{{/*
Expand the name of the chart.
*/}}
{{- define "grommunio.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "grommunio.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Chart name and version as used by the chart label.
*/}}
{{- define "grommunio.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels. Pass a dict with "root" (the top-level context) and
"component" (e.g. "core", "archive", "db-core").
*/}}
{{- define "grommunio.labels" -}}
helm.sh/chart: {{ include "grommunio.chart" .root }}
{{ include "grommunio.selectorLabels" . }}
app.kubernetes.io/version: {{ .root.Values.image.tag | default .root.Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .root.Release.Service }}
app.kubernetes.io/part-of: grommunio
{{- end }}

{{/*
Selector labels. Pass a dict with "root" and "component".
*/}}
{{- define "grommunio.selectorLabels" -}}
app.kubernetes.io/name: {{ include "grommunio.name" .root }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{/*
Image reference for a grommunio component built by the repo CI.
Pass a dict with "root" and "component" (gromox-core|gromox-archive|gromox-office).
*/}}
{{- define "grommunio.image" -}}
{{- printf "%s/%s-%s:%s" .root.Values.image.registry .root.Values.image.repository .component (.root.Values.image.tag | default "latest") }}
{{- end }}

{{/*
Service name of a database instance. Pass a dict with "root" and "key"
(core|chat|files|office|archive).
*/}}
{{- define "grommunio.dbHost" -}}
{{- printf "%s-db-%s" (include "grommunio.fullname" .root) .key }}
{{- end }}

{{/*
Map of database key -> enabled flag, derived from the feature toggles.
*/}}
{{- define "grommunio.enabledDatabases" -}}
{{- $dbs := dict "core" true "chat" .Values.features.chat.enabled "files" .Values.features.files.enabled "office" .Values.features.office.enabled "archive" .Values.features.archive.enabled -}}
{{- $dbs | toJson -}}
{{- end }}

{{/*
Name of the secret holding var.env.
*/}}
{{- define "grommunio.varEnvSecretName" -}}
{{- if .Values.existingVarEnvSecret }}
{{- .Values.existingVarEnvSecret }}
{{- else }}
{{- printf "%s-var-env" (include "grommunio.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Storage class line for a persistence entry. Pass a dict with "root" and
"claim" (the persistence sub-map). Renders nothing when no class is set.
*/}}
{{- define "grommunio.storageClass" -}}
{{- $class := .claim.storageClass | default .root.Values.persistence.storageClass -}}
{{- if $class }}
storageClassName: {{ $class | quote }}
{{- end }}
{{- end }}

{{/*
Shell snippet waiting for a list of "host:port" endpoints. Pass a dict with
"endpoints" (list of strings).
*/}}
{{- define "grommunio.waitForEndpoints" -}}
{{- range .endpoints }}
until nc -z -w 2 {{ (split ":" .)._0 }} {{ (split ":" .)._1 }}; do echo "waiting for {{ . }}"; sleep 2; done
{{- end }}
echo "all endpoints reachable"
{{- end }}
