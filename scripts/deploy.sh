#!/usr/bin/env bash
set -euo pipefail

command -v helm >/dev/null || { echo "helm is required" >&2; exit 1; }

values_args=(-f values.yaml)
if [[ -f secrets.local.yaml ]]; then
  values_args+=(-f secrets.local.yaml)
else
  echo "WARNING: secrets.local.yaml not found; demo credentials will be used." >&2
fi

helm dependency update
helm upgrade --install homelab . \
  --namespace homelab --create-namespace \
  "${values_args[@]}" \
  --wait --timeout 15m

kubectl get pods,ingress,pvc,hpa -n homelab

