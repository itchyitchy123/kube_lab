# Kubernetes Home Lab

A reproducible, portfolio-ready Kubernetes platform that runs a web tier, a stateful application stack, caching, and a complete metrics/logging observability stack.

## What this demonstrates

| Capability | Implementation |
|---|---|
| Package management | Umbrella Helm chart with configurable values and pinned dependency ranges |
| Web workloads | NGINX and WordPress Deployments with health probes and resource policies |
| Stateful workloads | MariaDB and Redis StatefulSets backed by persistent volume claims |
| Networking | ingress-nginx and host-based Ingress routes |
| Secrets | Kubernetes Secret references; local override file excluded from Git |
| Autoscaling | `autoscaling/v2` HPA for NGINX, driven by Metrics Server |
| Metrics | Prometheus Operator stack and persistent Prometheus storage |
| Dashboards | Grafana with Prometheus and Loki data sources |
| Logs | Promtail node agents ship container logs into single-binary Loki |
| Automation | Idempotent Bash scripts and GitHub Actions chart validation |

```text
Internet / localhost
        |
 ingress-nginx
    |       |
  NGINX  WordPress ---- MariaDB (PVC)
            |
          Redis (PVC)

Promtail --> Loki (PVC) --> Grafana <-- Prometheus (PVC)
```

## Prerequisites

- Docker
- kind
- kubectl
- Helm 3
- About 8 GB RAM and 4 CPU cores available to Docker

The project also works on k3s, MicroK8s, or an existing Kubernetes cluster. The bootstrap script is specifically for kind.

## Quick start

```bash
cp values.example.yaml secrets.local.yaml
# Edit secrets.local.yaml before deploying.
chmod +x scripts/*.sh
./scripts/bootstrap-kind.sh
./scripts/deploy.sh
./scripts/verify.sh
```

Add these entries to `/etc/hosts` if your resolver does not map them to localhost:

```text
127.0.0.1 nginx.homelab.local wordpress.homelab.local
127.0.0.1 grafana.homelab.local prometheus.homelab.local
```

Then open:

- `http://nginx.homelab.local`
- `http://wordpress.homelab.local`
- `http://grafana.homelab.local`
- `http://prometheus.homelab.local`

## Operations

```bash
# Inspect the platform
kubectl get pods,ingress,pvc,hpa -n homelab

# Watch autoscaling (generate traffic in another terminal)
kubectl get hpa -n homelab --watch
kubectl run load --rm -it --restart=Never --image=busybox:1.36 -- \
  sh -c 'while true; do wget -q -O- http://homelab-homelab-nginx; done'

# Upgrade after changing values
helm upgrade homelab . -n homelab -f values.yaml -f secrets.local.yaml

# Remove workloads (PVCs intentionally remain for data safety)
helm uninstall homelab -n homelab
```

## Design decisions and limitations

- MariaDB and Redis use StatefulSets because they require stable identities and storage. This is a learning environment, not a highly available database design.
- WordPress uses a `ReadWriteOnce` volume, so its HPA is disabled by default. To scale it safely, provide `ReadWriteMany` storage, switch the deployment strategy, and enable `wordpress.autoscaling.enabled`.
- Default passwords make `helm lint` and a demo install easy, but are intentionally obvious. Use `secrets.local.yaml`; in a production-style follow-up, integrate External Secrets or SOPS.
- Loki uses filesystem storage and a single replica to fit homelab resources. Object storage and distributed mode are the production evolution path.
- TLS is omitted so the lab works without a DNS name. cert-manager and a local CA or DNS-01 issuer are natural next steps.

## Repository layout

```text
templates/              Custom Kubernetes resources
scripts/                Cluster bootstrap, deploy, and smoke tests
.github/workflows/      CI validation
Chart.yaml              Helm metadata and observability dependencies
values.yaml             Defaults and service configuration
values.example.yaml     Safe template for local secret overrides
kind-config.yaml        Three-node local cluster
```

## Portfolio talking points

This lab shows the difference between Deployments and StatefulSets, why resource requests are required for CPU-based HPA, how Ingress separates routing from services, how PVC access modes constrain scaling, and how metrics and logs form complementary observability signals. Screenshots of Grafana dashboards, the Kubernetes resource inventory, and an HPA scaling event make useful additions to a project write-up.

