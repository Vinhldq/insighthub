{{/*
Expand the name of the chart.
*/}}
{{- define "insighthub.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "insighthub.fullname" -}}
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

{{/*
Chart name and version.
*/}}
{{- define "insighthub.chart" -}}
{{- .Chart.Name }}-{{ .Chart.Version | replace "+" "_" -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "insighthub.labels" -}}
helm.sh/chart: {{ include "insighthub.chart" . }}
app.kubernetes.io/name: {{ include "insighthub.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Match labels
*/}}
{{- define "insighthub.matchLabels" -}}
app.kubernetes.io/name: {{ include "insighthub.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Namespace
*/}}
{{- define "insighthub.namespace" -}}
{{- default .Release.Namespace .Values.namespace -}}
{{- end -}}
