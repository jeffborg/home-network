# Project: Home Network Infrastructure

Manage home Kubernetes cluster and associated infrastructure using Terraform and Flux CD.

## Dev Environment

Tools required: `terraform`, `kubectl`, `helm`, `flux` CLI.

`.mcp.json` runs the Flux Operator MCP server read-only (`brew install controlplaneio-fluxcd/tap/flux-operator-mcp`); pinned to the `home` context, reading `~/.kube/config`.

## Build & Deploy

### Flux CD (Kubernetes GitOps)
This repository uses Flux CD for GitOps management of Kubernetes resources. All Kubernetes manifests and Helm releases in `cluster/` are reconciled by Flux.

1.  **Syncing Changes:** Push changes to the Git repository. Flux automatically detects and applies them.
2.  **Flux CLI:** Use `flux` CLI for interaction (e.g., `flux get kustomizations`, `flux reconcile kustomization <name>`).
3.  **Helm Releases:** Helm charts are managed via `HelmRelease` custom resources in `cluster/apps/` and `cluster/core/`.

### Terraform (Infrastructure deployment)
1.  Ensure you are in the project root directory.
2.  Initialize Terraform: `terraform init`
3.  Review plan: `terraform plan`
4.  Apply changes: `terraform apply`

## Conventions

*   **GitOps:** Changes are applied via Git commits and CI/CD, though local commands are provided for development/troubleshooting.
*   **Directory Structure:**
    *   `cluster/`: Kubernetes manifests and Flux CD configurations (Kustomizations, HelmReleases).
    *   `router/`: Router configuration.
    *   `scripts/`: Utility scripts.

## New deployments

*   **No arch pinning** unless there's a genuine need (amd64-only image, hardware). Most images are multi-arch; check the manifest. To place a pod by capability, select on the NFD label (e.g. `feature.node.kubernetes.io/custom-vlan58: 'true'` for the VLAN 58 macvlan).
*   **Minimal PVC sizes.** Size for what the app actually stores, not a guess with headroom. Longhorn can expand a volume but never shrink it.
*   **Gateway API, not Ingress.** Use app-template `route:` HTTPRoutes on the `internal` Gateway (`<app>.${EXTERNAL_DOMAIN}`, `websecure`), plus a `web` redirect route; see `cluster/apps/media/jackett`.
*   **Homepage entry, every time.** Adding, removing or renaming an app with a web UI must update `cluster/apps/web-util/homepage/config/services.yaml` in the same PR. It is the dashboard everyone uses to find hosts, and it is routinely forgotten.

## Pitfalls

*   **Certificates:** Certificates may need to be disabled or handled carefully before Helm charts are installed, as noted in `README.md`.
*   **Terraform State:** Ensure correct `terraform.tfvars` or environment variables for target state.
*   **Flux substitution is strict:** any `${...}` under `cluster/core` or `cluster/apps` that isn't a cluster variable (a Grafana `${__url_time_range}`, a shell `${1}`) fails the whole Kustomization, and `apps` waits on `core`. Escape it as `$${...}` or use the unbraced `$var`; run `scripts/check-flux-substitution.sh` (CI does too).
