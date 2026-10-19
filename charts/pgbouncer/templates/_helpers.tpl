{{/*
Expand the name of the chart.
*/}}
{{- define "pgbouncer.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "pgbouncer.fullname" -}}
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
Create chart name and version as used by the chart label.
*/}}
{{- define "pgbouncer.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "pgbouncer.labels" -}}
helm.sh/chart: {{ include "pgbouncer.chart" . }}
{{ include "pgbouncer.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "pgbouncer.selectorLabels" -}}
app.kubernetes.io/name: {{ include "pgbouncer.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "pgbouncer.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "pgbouncer.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
pgbouncer.ini. listen_port follows service.port and auth_file points at the
userlist.txt the ExternalSecret renders; everything else comes from .Values.config.
Numbers are printed as integers, since Helm reads them as floats.
*/}}
{{- define "pgbouncer.ini.value" -}}
{{- if kindIs "float64" . }}{{ int64 . }}{{ else }}{{ . }}{{ end }}
{{- end }}

{{- define "pgbouncer.ini" -}}
[databases]
{{- range $name, $conn := .Values.config.databases }}
{{ $name }} = {{ $conn }}
{{- end }}

[pgbouncer]
listen_port = {{ .Values.service.port }}
auth_file = /etc/pgbouncer/userlist.txt
{{- range $key, $val := .Values.config.pgbouncer }}
{{ $key }} = {{ include "pgbouncer.ini.value" $val }}
{{- end }}
{{ end -}}
