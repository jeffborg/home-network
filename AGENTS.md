# Project: Home Network Infrastructure

Manage home Kubernetes cluster and associated infrastructure using Ansible and Terraform.

## Dev Environment

Tools required: `terraform`, `kubectl`, `helm`, `flux` CLI.

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

## Pitfalls

*   **Certificates:** Certificates may need to be disabled or handled carefully before Helm charts are installed, as noted in `README.md`.
*   **Terraform State:** Ensure correct `terraform.tfvars` or environment variables for target state.
