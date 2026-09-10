{{- define "catalog-service.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "catalog-service.fullname" -}}
{{- printf "%s" (include "catalog-service.name" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "catalog-service.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/name: {{ include "catalog-service.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "catalog-service.selectorLabels" -}}
app.kubernetes.io/name: {{ include "catalog-service.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}