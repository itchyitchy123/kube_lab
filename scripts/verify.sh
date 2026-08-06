#!/usr/bin/env bash
set -euo pipefail

namespace="${NAMESPACE:-homelab}"
kubectl wait --for=condition=Ready pod --all -n "${namespace}" --timeout=5m
kubectl get deployment,statefulset,service,ingress,pvc,hpa -n "${namespace}"

for host in nginx.homelab.local wordpress.homelab.local grafana.homelab.local prometheus.homelab.local; do
  status="$(curl --silent --output /dev/null --write-out '%{http_code}' --resolve "${host}:80:127.0.0.1" "http://${host}/")"
  [[ "${status}" =~ ^(200|301|302)$ ]] || { echo "${host}: HTTP ${status}" >&2; exit 1; }
  echo "${host}: HTTP ${status}"
done

