{{/*
Expand the name of the chart.
*/}}
{{- define "helm.name" -}}
{{- default .Chart.Name .Values.nameOverride | replace "_" "-" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "helm.fullname" -}}
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
{{- define "helm.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "helm.labels" -}}
helm.sh/chart: {{ include "helm.chart" . }}
{{ include "helm.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "helm.selectorLabels" -}}
app.kubernetes.io/name: {{ include "helm.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "helm.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "helm.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "helm.backupServiceAccountName" -}}
{{- if .Values.backupServiceAccount.create }}
{{- default (printf "%s-backup" (include "helm.fullname" .)) .Values.backupServiceAccount.name }}
{{- else }}
{{- default "default" .Values.backupServiceAccount.name }}
{{- end }}
{{- end }}

{{- define "helm.pvcName" -}}
{{- if .Values.vaultwarden.persistence.existingClaim -}}
{{- .Values.vaultwarden.persistence.existingClaim -}}
{{- else -}}
{{- printf "%s-%s" (include "helm.fullname" .) .Values.vaultwarden.persistence.name -}}
{{- end -}}
{{- end }}

{{- define "helm.headlessServiceName" -}}
{{- printf "%s-headless" (include "helm.fullname" .) -}}
{{- end }}

{{- define "helm.vaultwardenName" -}}
{{- printf "%s-vaultwarden" (include "helm.fullname" .) -}}
{{- end }}

{{- define "helm.vaultwardenBackupName" -}}
{{- printf "%s-vaultwarden-backup" (include "helm.fullname" .) -}}
{{- end }}

{{- define "helm.resticRestoreName" -}}
{{- printf "%s-restic-restore" (include "helm.fullname" .) -}}
{{- end }}

{{- define "helm.resticBackupName" -}}
{{- printf "%s-restic-backup" (include "helm.fullname" .) -}}
{{- end }}

{{- define "helm.backupCronJobName" -}}
{{- printf "%s-backup" (include "helm.fullname" .) -}}
{{- end }}

{{- define "helm.resticEnvSecretName" -}}
{{- printf "%s-restic-env" (include "helm.fullname" .) -}}
{{- end }}

{{- define "helm.backupRoleName" -}}
{{- printf "%s-backup" (include "helm.fullname" .) -}}
{{- end }}
