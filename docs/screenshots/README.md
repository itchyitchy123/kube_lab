# Portfolio screenshots

Capture these after the cluster is running. The screenshots should come from the live dashboards, not from a mock UI.

## Grafana

1. Open `http://grafana.homelab.local` and sign in with the password from `secrets.local.yaml`.
2. Open Kubernetes / Compute Resources / Namespace (Pods).
3. Select the `homelab` namespace and capture pod CPU/memory and replica activity.
4. Save it as `docs/screenshots/grafana-homelab.png`.

## Prometheus

1. Open `http://prometheus.homelab.local/targets`.
2. Capture the page showing Kubernetes, node, and kube-state-metrics targets healthy.
3. Save it as `docs/screenshots/prometheus-targets.png`.

For stronger evidence, capture the terminal output from the demo script at the HPA and MariaDB sections too.

Useful terminal captures:

```bash
kubectl get pods,svc,pvc,hpa -n homelab
kubectl get hpa homelab-homelab-nginx -n homelab --watch
```

Keep one capture showing the normal two-replica state and another showing the HPA desired replica count increasing under load. The demo script then records the return to the minimum and the MariaDB marker surviving pod replacement.
