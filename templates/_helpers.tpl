{{- define "homelab.name" -}}kubernetes-homelab{{- end }}
{{- define "homelab.fullname" -}}{{ .Release.Name }}-homelab{{- end }}
{{- define "homelab.labels" -}}
app.kubernetes.io/part-of: {{ include "homelab.name" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end }}
{{- define "homelab.selectorLabels" -}}
app.kubernetes.io/name: {{ .component }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
{{- end }}

