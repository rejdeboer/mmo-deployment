# mmo-deployment

This repo contains a blueprint for deploying a mmo-server to a k3s onprem cluster.

## Technologies

- Terraform
- Flux CD
- Kubernetes (K3S)
- Proxmox
- Hashicorp Vault
- Minio

## Project structure

- `terraform`: contains terraform blueprint for bootstrapping Proxmox cluster with infra, and bootstrapping the Kubernetes cluster. Only the onprem directory is relevant for now.
- `clusters`: Flux CD K8S cluster bootstrapping manifests per environment. The huge files in `flux-system` directory can be ignored.
- `kubernetes`: Contains the k8s manifests managed by Flux. It has modules:
    - `system`: Manifests that deploy core resources like secrets and Metallb
    - `platform`: Manifests for platform technologies, like observability using LGTM stack
    - `apps`: Manifests for applications
- `operator`: Can be ignored for now, contains code that could be used for custom realm operator
