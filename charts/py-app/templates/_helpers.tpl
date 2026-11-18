{{/*
Expand the name of the chart.
*/}}
{{- define "py-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "py-app.fullname" -}}
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
{{- define "py-app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "py-app.labels" -}}
helm.sh/chart: {{ include "py-app.chart" . }}
{{ include "py-app.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "py-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "py-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "py-app.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "py-app.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create env definition for the deployments.

This variable shoule be used in all places where the same envs as in
the main deployment are required. 
*/}}
{{- define "py-app.envs" -}}
{{- with .Values.env }}
env:
    {{- range $key, $val := . }}
    - name: {{ $key }}
      value: {{ tpl (print $val) $ | quote }}
    {{- end }}
{{- end }}
{{- with .Values.externalSecrets }}
envFrom:
    {{- range $name, $val := . }}
    - secretRef:
        name: {{ $val.targetName }} 
    {{- end }}
{{- end }}
{{ end -}}

{{/*
The Portcullis WAF sidecar, as a native sidecar (an init container with
restartPolicy: Always). It starts before the app and stops after it.

The startup probe must not depend on the app: the kubelet starts the app
container only once this one has started, while /readyz stays 503 until the
sidecar has fetched the app's OpenAPI document. So startup and liveness use
/healthz, and only readiness uses /readyz.
*/}}
{{- define "py-app.wafSidecar" -}}
- name: waf
  image: "{{ required "waf.image.repository is required when waf.enabled" .Values.waf.image.repository }}:{{ required "waf.image.tag is required when waf.enabled" .Values.waf.image.tag }}"
  imagePullPolicy: {{ .Values.waf.image.pullPolicy }}
  restartPolicy: Always
  env:
    - name: PORTCULLIS_CONFIG
      value: /etc/portcullis/config.toml
    {{- if .Values.waf.globalConfigMap }}
    - name: PORTCULLIS_GLOBAL_FILE
      value: /etc/portcullis-global/waf-global
    {{- end }}
  ports:
    - name: waf
      containerPort: {{ .Values.waf.port }}
      protocol: TCP
    - name: waf-admin
      containerPort: {{ .Values.waf.adminPort }}
      protocol: TCP
  startupProbe:
    httpGet:
      path: /healthz
      port: waf-admin
    periodSeconds: 1
    failureThreshold: 30
  livenessProbe:
    httpGet:
      path: /healthz
      port: waf-admin
    periodSeconds: 10
    failureThreshold: 3
  readinessProbe:
    httpGet:
      path: /readyz
      port: waf-admin
    periodSeconds: 2
    failureThreshold: 3
  securityContext:
    runAsNonRoot: true
    runAsUser: 65532
    runAsGroup: 65532
    readOnlyRootFilesystem: true
    allowPrivilegeEscalation: false
    capabilities:
      drop: ["ALL"]
    seccompProfile:
      type: RuntimeDefault
  resources:
    {{- toYaml .Values.waf.resources | nindent 4 }}
  volumeMounts:
    # Mounted as a directory, not with subPath, so edits reach the running pod.
    - name: waf-config
      mountPath: /etc/portcullis
      readOnly: true
    {{- if .Values.waf.globalConfigMap }}
    - name: waf-global
      mountPath: /etc/portcullis-global
      readOnly: true
    {{- end }}
{{- end }}

{{/*
The sidecar's config file, written key by key. Helm's toToml would turn every
integer into a float, which the sidecar refuses. waf.extraConfig is appended
verbatim for anything not modelled here.
*/}}
{{- define "py-app.wafConfig" -}}
mode = {{ .Values.waf.mode | quote }}
kill_switch = {{ .Values.waf.killSwitch }}
trusted_peers = {{ .Values.waf.trustedPeers | toJson }}

[listen]
proxy = "0.0.0.0:{{ int .Values.waf.port }}"
admin = "0.0.0.0:{{ int .Values.waf.adminPort }}"

[upstream]
addr = "127.0.0.1:{{ int .Values.waf.appPort }}"

[spec]
enabled = {{ .Values.waf.spec.enabled }}
path = {{ .Values.waf.specPath | quote }}
allow = {{ .Values.waf.spec.allow | toJson }}
deny = {{ .Values.waf.spec.deny | toJson }}
{{- with .Values.waf.extraConfig }}

{{ . | trim }}
{{- end }}
{{- end }}
