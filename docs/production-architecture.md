# Production Architecture Decision

## Context

The current setup uses Proxmox with K3s on-prem. For production, we need a reliable, cost-effective infrastructure that can handle sustained game server workloads without the high costs of public cloud providers.

## Decision

### Compute: Hetzner Dedicated Servers with Talos Linux

We will run the Kubernetes cluster on Hetzner dedicated servers using Talos Linux as the OS.

**Why Hetzner:**
- 50-80% cheaper than cloud for sustained compute (which game servers are)
- Multiple datacenter locations in Europe
- Managed hardware (they handle disk/node failures)
- No egress fees for traffic between dedicated servers in the same datacenter

**Why Talos over K3s:**
- Immutable OS — no SSH, no shell, no configuration drift
- Declarative machine configuration — nodes are cattle, not pets
- Secure by default — minimal attack surface, no package manager
- Atomic upgrades with automatic rollback
- First-class support for bare-metal deployments

### Secrets: Vault on a Separate VM

Vault runs on a standalone Hetzner Cloud VM, outside the Kubernetes cluster.

**Rationale:**
- Avoids the chicken-and-egg problem: the cluster needs secrets to bootstrap, so Vault cannot live inside the cluster it bootstraps
- Reduces blast radius: if the cluster is compromised or goes down, Vault remains isolated
- Simpler unsealing: a standalone VM avoids pod scheduling issues during unseal

**Unsealing strategy:** Shamir keys with manual unseal. Reboots should be rare on a cloud VM. Automate later if it becomes a pain.

**Secret delivery to the cluster:** External Secrets Operator syncs secrets from Vault into Kubernetes.

## Target Architecture

```
Hetzner Cloud VM (small, e.g. CX22)
└── Vault (single node, Shamir unseal)

Hetzner Dedicated Servers
├── Talos control plane (3 nodes)
├── Talos worker nodes (game servers + platform workloads)
└── Flux CD (GitOps, pulls from this repo)
        └── External Secrets Operator -> Vault
```

## What stays the same

- Flux CD and all GitOps manifests (clusters/, deploy/, platform/, etc.)
- Application deployment model
- Observability stack (LGTM)

## What changes

- Terraform: rewrite from Proxmox provider to Hetzner + Talos machine configs
- Minio: evaluate replacement with Hetzner Object Storage
- Networking: no native LB; need floating IP or external solution
