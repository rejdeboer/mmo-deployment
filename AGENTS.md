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

- `terraform`: contains terraform blueprint for bootstrapping Proxmox cluster with infra, and bootstrapping the Kubernetes cluster
- `clusters`: Flux CD K8S cluster bootstrapping manifests per environment
- `system`: Manifests that deploy core resources like secrets and Metallb
- `platform`: Manifests for platform technologies, like observability using LGTM stack
- `infra`: WIP, target architecture directory for the Flux CD refactor
- `deploy`: Manifests for applications
- `pre-deploy`: Manifests that should be deployed before applications, should probably be called `provisioning`
- `operator`: Can be ignored for now, contains code that could be used for custom realm operator
