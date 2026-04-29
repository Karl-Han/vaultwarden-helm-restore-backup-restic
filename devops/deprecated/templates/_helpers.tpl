{{/*
Expand the name of the chart.
*/}}
{{- define "vaultwarden_backup.name" -}}
{{- default .Chart.Name .Values.nameOverride | replace "_" "-" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "vaultwarden_backup.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | replace "_" "-" | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride | replace "_" "-" }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | replace "_" "-" | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" (.Release.Name | replace "_" "-") $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "vaultwarden_backup.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "vaultwarden_backup.labels" -}}
helm.sh/chart: {{ include "vaultwarden_backup.chart" . }}
{{ include "vaultwarden_backup.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "vaultwarden_backup.selectorLabels" -}}
app.kubernetes.io/name: {{ include "vaultwarden_backup.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "vaultwarden_backup.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "vaultwarden_backup.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the backup service account to use
*/}}
{{- define "vaultwarden_backup.backupServiceAccountName" -}}
{{- if .Values.backupServiceAccount.create }}
{{- default (printf "%s-backup" (include "vaultwarden_backup.fullname" .)) .Values.backupServiceAccount.name }}
{{- else }}
{{- default "default" .Values.backupServiceAccount.name }}
{{- end }}
{{- end }}

{{/*
Chart namespace
*/}}
{{- define "vaultwarden_backup.namespace" -}}
{{- default .Release.Namespace .Values.namespace -}}
{{- end }}

{{/*
PVC name
*/}}
{{- define "vaultwarden_backup.pvcName" -}}
{{- if .Values.vaultwarden.persistence.existingClaim -}}
{{- .Values.vaultwarden.persistence.existingClaim -}}
{{- else -}}
{{- printf "%s-data" (include "vaultwarden_backup.fullname" .) -}}
{{- end -}}
{{- end }}

{{/*
Vaultwarden workload name
*/}}
{{- define "vaultwarden_backup.vaultwardenName" -}}
{{- printf "%s-vaultwarden" (include "vaultwarden_backup.fullname" .) -}}
{{- end }}

{{/*
Backup CronJob name
*/}}
{{- define "vaultwarden_backup.backupCronJobName" -}}
{{- printf "%s-backup" (include "vaultwarden_backup.fullname" .) -}}
{{- end }}

{{/*
Render same-node pod affinity against the Vaultwarden workload.
*/}}
{{- define "vaultwarden_backup.sharedVolumeAffinity" -}}
{{- if .Values.affinity.enabled }}
podAffinity:
  requiredDuringSchedulingIgnoredDuringExecution:
    - labelSelector:
        matchExpressions:
          - key: app.kubernetes.io/component
            operator: In
            values:
              - vaultwarden
          - key: app.kubernetes.io/instance
            operator: In
            values:
              - {{ .Release.Name | quote }}
      topologyKey: {{ .Values.affinity.sameNode.topologyKey | quote }}
{{- end }}
{{- end }}
