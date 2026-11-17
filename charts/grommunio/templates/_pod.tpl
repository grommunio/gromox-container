{{/* Secret keys each container gets */}}
{{- define "grommunio.secretKeysFor" -}}
{{- if eq . "core" -}}ADMIN_PASS MYSQL_PASS CHAT_MYSQL_PASS CHAT_ADMIN_PASS KEYCLOAK_CLIENT_SECRET
{{- else if eq . "archive" -}}ADMIN_PASS ARCHIVE_MYSQL_PASS ARCHIVE_ADMIN_PASS ARCHIVE_AUDIT_PASS
{{- else if eq . "office" -}}FILES_MYSQL_PASS FILES_ADMIN_PASS OFFICE_MYSQL_PASS OFFICE_JWT_SECRET
{{- end -}}
{{- end -}}

{{/* Environment of the application containers:
     include "grommunio.appEnv" (dict "root" . "component" "core") */}}
{{- define "grommunio.appEnv" -}}
{{- $c := index .root.Values .component -}}
envFrom:
  - configMapRef:
      name: {{ include "grommunio.fullname" .root }}-env
  {{- with .root.Values.grommunio.extraEnvFrom }}
  {{- toYaml . | nindent 2 }}
  {{- end }}
{{- $env := concat .root.Values.grommunio.extraEnv $c.extraEnv }}
env:
  {{- range $k := splitList " " (include "grommunio.secretKeysFor" .component) }}
  - name: {{ $k }}
    valueFrom:
      secretKeyRef:
        name: {{ include "grommunio.secretName" $.root }}
        key: {{ $k }}
        {{- /* keys an existingSecret may omit */}}
        {{- if has $k (list "KEYCLOAK_CLIENT_SECRET" "ARCHIVE_ADMIN_PASS" "ARCHIVE_AUDIT_PASS" "OFFICE_JWT_SECRET" "CHAT_ADMIN_PASS" "CHAT_MYSQL_PASS" "FILES_ADMIN_PASS" "FILES_MYSQL_PASS" "OFFICE_MYSQL_PASS" "ARCHIVE_MYSQL_PASS") }}
        optional: true
        {{- end }}
  {{- end }}
  {{- if and (eq .component "core") .root.Values.maintenance.clearDbs }}
  - name: MYSQL_ROOT_PASS
    valueFrom:
      secretKeyRef:
        name: {{ include "grommunio.rootSecretName" .root }}
        key: MYSQL_ROOT_PASS
  {{- end }}
  {{- with $env }}
  {{- toYaml . | nindent 2 }}
  {{- end }}
{{- end -}}

{{/* Volumes every application pod has: TLS secret, working ssl dir, /run, /tmp */}}
{{- define "grommunio.commonVolumes" -}}
- name: tls
  secret:
    secretName: {{ include "grommunio.tlsSecretName" . }}
    defaultMode: 0400
- name: ssl
  emptyDir: {}
- name: run
  emptyDir:
    medium: Memory
    sizeLimit: 256Mi
- name: tmp
  emptyDir: {}
{{- end -}}

{{- define "grommunio.commonVolumeMounts" -}}
- name: tls
  mountPath: /etc/grommunio-common/ssl/own
  readOnly: true
- name: ssl
  mountPath: /etc/grommunio-common/ssl
- name: run
  mountPath: /run
- name: tmp
  mountPath: /tmp
{{- end -}}

{{/* Pod volume for a persistence entry with existingClaim; without it the
     volumeClaimTemplate of the same name is used.
     include "grommunio.pvcVolume" (dict "name" "data" "spec" .Values.persistence.core.data) */}}
{{- define "grommunio.pvcVolume" -}}
{{- if .spec.existingClaim }}
- name: {{ .name }}
  persistentVolumeClaim:
    claimName: {{ .spec.existingClaim }}
{{- end }}
{{- end -}}

{{/* volumeClaimTemplate entry; include "grommunio.pvcTemplate" (dict "root" . "name" "data" "spec" ...) */}}
{{- define "grommunio.pvcTemplate" -}}
{{- if not .spec.existingClaim }}
- metadata:
    name: {{ .name }}
    {{- with .spec.annotations }}
    annotations:
      {{- toYaml . | nindent 6 }}
    {{- end }}
  spec:
    accessModes: ["ReadWriteOnce"]
    {{- $sc := default .root.Values.global.storageClass .spec.storageClass }}
    {{- if $sc }}
    storageClassName: {{ ternary "" $sc (eq $sc "-") | quote }}
    {{- end }}
    resources:
      requests:
        storage: {{ .spec.size }}
{{- end }}
{{- end -}}
