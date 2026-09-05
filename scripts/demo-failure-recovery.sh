#!/usr/bin/env bash
set -euo pipefail

namespace="${NAMESPACE:-homelab}"
release="${RELEASE_NAME:-homelab}"
prefix="${release}-homelab"
nginx_deployment="${prefix}-nginx"
nginx_service="${prefix}-nginx"
load_pods=("${prefix}-load-1" "${prefix}-load-2" "${prefix}-load-3" "${prefix}-load-4")

command -v kubectl >/dev/null || { echo "kubectl is required" >&2; exit 1; }
cleanup() {
  kubectl delete pod "${load_pods[@]}" -n "${namespace}" --ignore-not-found >/dev/null 2>&1 || true
  kubectl patch deployment "${nginx_deployment}" -n "${namespace}" --type=json \
    -p='[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/"}]' >/dev/null 2>&1 || true
}
trap cleanup EXIT
section() { printf '\n=== %s ===\n' "$1"; }

section "1. Delete an application pod: Deployment recreates it"
before="$(kubectl get pods -n "${namespace}" -l app.kubernetes.io/name=nginx -o jsonpath='{.items[0].metadata.name}')"
echo "Deleting ${before}"
kubectl delete pod "${before}" -n "${namespace}" --wait=false
kubectl rollout status deployment "${nginx_deployment}" -n "${namespace}" --timeout=120s
kubectl get pods -n "${namespace}" -l app.kubernetes.io/name=nginx -o wide

section "2. Break readiness: Service removes the pod from routing"
kubectl patch deployment "${nginx_deployment}" -n "${namespace}" --type=json \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/intentionally-not-ready"}]'
sleep 12
kubectl get pods -n "${namespace}" -l app.kubernetes.io/name=nginx -o wide
kubectl get endpoints "${nginx_service}" -n "${namespace}" -o wide
echo "Restoring the readiness probe"
kubectl patch deployment "${nginx_deployment}" -n "${namespace}" --type=json \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/"}]'
kubectl rollout status deployment "${nginx_deployment}" -n "${namespace}" --timeout=120s

section "3. Increase load: HPA scales NGINX replicas"
min_replicas="$(kubectl get hpa "${nginx_deployment}" -n "${namespace}" -o jsonpath='{.spec.minReplicas}')"
echo "Normal state: minReplicas=${min_replicas}"
for load_pod in "${load_pods[@]}"; do
  kubectl run "${load_pod}" -n "${namespace}" --image=busybox:1.36 --restart=Never -- \
    sh -c "while true; do wget -q -O- http://${nginx_service} >/dev/null; done" >/dev/null
done
for _ in $(seq 1 36); do
  kubectl get hpa "${nginx_deployment}" -n "${namespace}"
  desired="$(kubectl get hpa "${nginx_deployment}" -n "${namespace}" -o jsonpath='{.status.desiredReplicas}' 2>/dev/null || true)"
  if [[ "${desired:-0}" =~ ^[0-9]+$ ]] && (( desired > min_replicas )); then
    echo "HPA scaled desired replicas to ${desired}."
    break
  fi
  sleep 5
done
echo "Removing load; waiting for HPA to return to ${min_replicas} replicas"
kubectl delete pod "${load_pods[@]}" -n "${namespace}" --ignore-not-found
for _ in $(seq 1 48); do
  kubectl get hpa "${nginx_deployment}" -n "${namespace}"
  desired="$(kubectl get hpa "${nginx_deployment}" -n "${namespace}" -o jsonpath='{.status.desiredReplicas}' 2>/dev/null || true)"
  if [[ "${desired:-0}" == "${min_replicas}" ]]; then
    echo "HPA returned to ${min_replicas} desired replicas after load removal."
    break
  fi
  sleep 5
done

section "4. Delete MariaDB pod: StatefulSet remounts the same PVC"
mariadb_pod="$(kubectl get pod -n "${namespace}" -l app.kubernetes.io/name=mariadb -o jsonpath='{.items[0].metadata.name}')"
root_password="$(kubectl get secret "${prefix}-credentials" -n "${namespace}" -o jsonpath='{.data.mariadb-root-password}' | base64 --decode)"
marker="recovery-$(date +%s)"
kubectl exec -n "${namespace}" "${mariadb_pod}" -- mariadb -uroot -p"${root_password}" -e \
  "CREATE TABLE IF NOT EXISTS wordpress.recovery_probe (id VARCHAR(128) PRIMARY KEY); INSERT IGNORE INTO wordpress.recovery_probe VALUES ('${marker}');"
kubectl delete pod "${mariadb_pod}" -n "${namespace}" --wait=false
kubectl wait --for=condition=ready pod "${mariadb_pod}" -n "${namespace}" --timeout=180s
kubectl exec -n "${namespace}" "${mariadb_pod}" -- mariadb -uroot -p"${root_password}" wordpress -N \
  -e "SELECT id FROM recovery_probe WHERE id='${marker}';"
echo "PVC-backed marker ${marker} survived MariaDB pod replacement."
