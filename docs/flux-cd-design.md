# Flux CD Deployment Design

## Context

The current Flux CD structure uses a `system/` + `platform/` split, each with
`controllers/` and `configs/` subdirectories, plus `pre-deploy/` and `deploy/`.
This creates a 4-level sequential dependency chain that doesn't scale well:

```
system-controllers -> system-configs -> platform-controllers -> platform-configs
                                    \-> pre-deploy -> deploy
```

### Problems with the current structure

1. **Missing dependency from deploy to platform**: `deploy` depends on
   `pre-deploy` but NOT on `platform-configs`. The game-server Fleet needs
   Agones, the web-server needs TLS certificates (cert-manager), and the
   PostgreSQL connection needs CNPG. These are implicit dependencies that
   cause failures on fresh bootstrap.

2. **Missing dependency from pre-deploy to platform-configs**: The db-migration
   Job connects to `postgres-main-rw` (the CNPG Cluster), but `pre-deploy`
   only depends on `system-configs`. The CNPG Cluster is created in
   `platform-configs`, which is a sibling, not a predecessor. This is a race
   condition.

3. **Unnecessary sequencing**: `platform-controllers` waits for `system-configs`
   even though installing Agones, cert-manager, and CNPG operators doesn't
   require MetalLB config or Vault secrets.

4. **Scattered concerns**: The `system/` vs `platform/` split is arbitrary.
   Both contain infrastructure controllers and their configs. The distinction
   adds cognitive overhead without benefit.

5. **Orphaned manifests**: `ingress-nginx.yml`, `rustfs.yml` exist in the tree
   but aren't referenced in any kustomization.

6. **Mixed API versions**: `loki` uses `helm.toolkit.fluxcd.io/v2beta2` while
   everything else uses `v2`.

## Real Dependency Map

Analysis of every controller's actual runtime dependencies:

```
MetalLB (standalone)
  └─> Traefik Service (needs LoadBalancer IP)
       └─> All Ingress resources

ESO (standalone)
  └─> ClusterSecretStore + ExternalSecrets
       ├─> pg-secret         -> CNPG Cluster, game-server, web-server, provisioner, db-migration
       ├─> netcode-secret    -> game-server, web-server, provisioner
       ├─> jwt-secret        -> web-server
       ├─> cloudflare-secret -> external-dns, cert-manager ClusterIssuer
       ├─> tempo-s3          -> Tempo
       ├─> loki-s3           -> Loki
       ├─> mimir-s3          -> Mimir
       └─> grafana-admin     -> Grafana

Prometheus CRDs (standalone)
  └─> ServiceMonitors (game-server, web-server)
  └─> PodMonitors (flux-system)
  └─> k8s-monitoring (discovers ServiceMonitors/PodMonitors)
```

Key insight: **most cross-controller dependencies flow through ESO secrets**,
not through controllers depending on each other directly. MetalLB, ESO, and
Prometheus CRDs are true foundational controllers. Everything else either
consumes secrets or consumes CRDs from those three.

## Design Principles

Following the [official Flux monorepo pattern](https://github.com/fluxcd/flux2-kustomize-helm-example),
adapted for a mixed-content repo:

1. **Single `kubernetes/` root**: All Flux-managed manifests live under one
   directory to keep the repo root clean for terraform, operator code, etc.

2. **Three layers of infrastructure**: `controllers` -> `configs` ->
   `observability`. Controllers install operators and CRDs. Configs create
   custom resources (secrets, IP pools, CNPG cluster). Observability depends
   on configs because Loki/Mimir/Tempo need S3 secrets from ESO.

3. **`dependsOn` models real needs, not per-controller chains**: Dependencies
   are expressed at the layer level. Within a layer, Flux's retry mechanism
   handles transient ordering. The goal is: if a layer's `dependsOn` targets
   are all healthy, everything in that layer should be able to reconcile.

4. **Base/overlay pattern for environments**: Kustomize overlays for
   environment-specific values (staging, production).

5. **One file per component**: Each controller gets its own file containing
   its namespace, HelmRepository, and HelmRelease. Keeps diffs reviewable.

### Why NOT per-controller Kustomizations

It's tempting to create a Flux Kustomization per controller with fine-grained
`dependsOn` chains:

```
# ANTI-PATTERN
metallb -> metallb-config -> eso -> eso-config -> cert-manager -> ...
```

Problems:
- **Fragile**: one stuck component blocks everything downstream
- **Overhead**: each Kustomization is an independent reconciliation loop,
  increasing API server load and memory usage
- **Unnecessary**: most "dependencies" are soft -- a HelmRelease that needs a
  secret will simply have pods in CrashLoopBackOff until the secret appears;
  Flux and Kubernetes both retry automatically
- **Hard `dependsOn`**: MetalLB doesn't need to be fully healthy for cert-manager
  to install. Cert-manager doesn't need MetalLB at all. These controllers are
  independent; only their *configs* interact.

The correct granularity is **layer-level**, not component-level.

## Target Directory Structure

```
kubernetes/                           # All Flux-managed K8s manifests
├── infrastructure/
│   ├── controllers/                  # Layer 1: CRDs + operators (no external deps)
│   │   ├── kustomization.yaml
│   │   ├── agones.yaml               # HelmRepo + HelmRelease
│   │   ├── cert-manager.yaml         # Namespace + HelmRepo + HelmRelease
│   │   ├── cnpg.yaml                 # HelmRepo + HelmRelease
│   │   ├── external-secrets.yaml     # HelmRepo + HelmRelease + GitRepo + CRD Kustomization
│   │   ├── metallb.yaml              # HelmRepo + HelmRelease
│   │   └── prometheus-crds.yaml      # HelmRepo + HelmRelease
│   └── configs/                      # Layer 2: Custom resources (need CRDs + operators)
│       ├── kustomization.yaml
│       ├── cluster-issuers.yaml      # ClusterIssuer + Certificates
│       ├── cnpg.yaml                 # CNPG Cluster (postgres-main)
│       ├── external-secrets.yaml     # ClusterSecretStore + all ExternalSecrets
│       ├── metallb.yaml              # IPAddressPool + L2Advertisement
│       ├── namespaces.yaml           # monitoring namespace, etc.
│       └── traefik.yaml              # HelmChartConfig for K3S traefik
├── observability/
│   ├── controllers/                  # Layer 3: Monitoring stack (needs secrets from Layer 2)
│   │   ├── kustomization.yaml
│   │   ├── repositories.yaml         # HelmRepositories: grafana-charts, grafana-community
│   │   ├── grafana.yaml              # HelmRelease (needs grafana-admin secret)
│   │   ├── loki.yaml                 # HelmRelease (needs loki-s3 secret)
│   │   ├── mimir.yaml                # HelmRelease (needs mimir-s3 secret)
│   │   ├── tempo.yaml                # HelmRelease + NetworkPolicy (needs tempo-s3 secret)
│   │   └── k8s-monitoring.yaml       # HelmRelease (pushes to loki/mimir/tempo)
│   └── configs/                      # Layer 4: Dashboards + monitors
│       ├── kustomization.yaml
│       ├── podmonitor.yaml           # PodMonitor: flux-system
│       └── dashboards/
│           ├── control-plane.json
│           ├── cluster.json
│           └── game-server.json
├── apps/
│   ├── base/
│   │   ├── kustomization.yaml
│   │   ├── namespace.yaml
│   │   ├── assets-config.yaml
│   │   ├── game-server-config.yaml
│   │   ├── game-server.yaml          # Agones Fleet + Service + ServiceMonitor
│   │   ├── web-server.yaml           # Deployment + Service + SA + RBAC + NetworkPolicy + ServiceMonitor
│   │   ├── external-dns.yaml         # SA + ClusterRole + ClusterRoleBinding + Deployment
│   │   └── ingress.yaml              # Ingress: web-server, grafana
│   └── staging/
│       ├── kustomization.yaml        # Overlay: patches + image overrides
│       ├── provisioner.yaml          # Deployment + Service + Ingress
│       └── patches/
│           └── game-server-config-patch.yaml
└── automation/
    ├── kustomization.yaml
    ├── image-repositories.yaml       # ImageRepository x4
    ├── image-policies.yaml           # ImagePolicy x4
    ├── image-update-automation.yaml  # ImageUpdateAutomation
    └── migration-job.yaml            # Job: db-migration

clusters/
└── staging/
    ├── flux-system/
    │   ├── gotk-components.yaml
    │   ├── gotk-sync.yaml
    │   └── kustomization.yaml
    ├── infrastructure.yaml           # Defines: infra-controllers, infra-configs
    ├── observability.yaml            # Defines: obs-controllers, obs-configs
    ├── automation.yaml               # Defines: automation
    └── apps.yaml                     # Defines: apps
```

Other repo directories (`terraform/`, `operator/`, etc.) remain at root,
unaffected.

## Flux Kustomization Dependency Graph

```
flux-system (root, path: clusters/staging)
│
├── infra-controllers           path: ./kubernetes/infrastructure/controllers
│   │                           dependsOn: []
│   │
│   └── infra-configs           path: ./kubernetes/infrastructure/configs
│       │                       dependsOn: [infra-controllers]
│       │
│       ├── obs-controllers     path: ./kubernetes/observability/controllers
│       │   │                   dependsOn: [infra-configs]
│       │   │
│       │   └── obs-configs     path: ./kubernetes/observability/configs
│       │                       dependsOn: [obs-controllers]
│       │
│       ├── automation          path: ./kubernetes/automation
│       │                       dependsOn: [infra-configs]
│       │
│       └── apps                path: ./kubernetes/apps/staging
│                               dependsOn: [infra-configs, automation]
```

### Execution timeline

```
Phase 1 ─── infra-controllers
             MetalLB, ESO, cert-manager, CNPG operator, Agones, Prometheus CRDs
             (all install independently, no cross-deps at controller level)

Phase 2 ─── infra-configs
             ClusterSecretStore, all ExternalSecrets, IPAddressPool,
             L2Advertisement, Traefik config, CNPG Cluster, ClusterIssuer,
             Certificates, monitoring namespace
             (needs CRDs from Phase 1; ESO syncs all secrets from Vault)

Phase 3 ─── obs-controllers ──── automation
  (parallel)  Loki, Tempo, Mimir    ImageRepos, ImagePolicies,
              Grafana, k8s-mon      ImageUpdateAutomation,
              (need S3 + admin       db-migration Job
              secrets from Phase 2)  (needs CNPG cluster from Phase 2)

Phase 4 ─── obs-configs ────── apps
  (parallel)  PodMonitors,          game-server Fleet, web-server,
              dashboards             provisioner, external-dns, ingress
                                    (needs Agones CRDs, secrets, CNPG,
                                     certs -- all from Phase 2;
                                     needs db-migration from Phase 3)
```

### Why each dependency exists

| Relationship | Reason |
|---|---|
| `infra-configs` -> `infra-controllers` | Configs create custom resources (ClusterIssuer, IPAddressPool, CNPG Cluster, ExternalSecrets) that need CRDs from controllers to exist |
| `obs-controllers` -> `infra-configs` | Loki, Mimir, Tempo mount S3 secrets created by ESO in infra-configs. Grafana mounts grafana-admin secret. All need the monitoring namespace. |
| `obs-configs` -> `obs-controllers` | PodMonitors and dashboard ConfigMaps need Prometheus CRDs and Grafana sidecar to be running |
| `automation` -> `infra-configs` | db-migration Job needs pg-secret (ESO) and postgres-main-rw (CNPG Cluster), both created in infra-configs |
| `apps` -> `infra-configs` | Apps need Agones CRDs, secrets (pg, netcode, jwt, cloudflare), CNPG cluster, TLS certs |
| `apps` -> `automation` | Apps should only deploy after db-migration has run |

### How MetalLB and ESO dependencies are handled

These are the two controllers that many other things depend on. The key insight
is that they are handled **at the layer boundary**, not per-controller:

**MetalLB**: The controller installs in Phase 1. Its IPAddressPool and
L2Advertisement are applied in Phase 2 (infra-configs). Traefik's Service gets
its annotation in the same Phase 2. By the time Phase 3/4 workloads create
Ingresses, MetalLB is fully configured. No per-controller `dependsOn` needed.

**ESO**: The operator installs in Phase 1. The ClusterSecretStore and all
ExternalSecrets are created in Phase 2. By the time Phase 3 (observability)
and Phase 4 (apps) run, all secrets exist. The layer boundary is the
synchronization point.

If a secret takes longer to sync from Vault, the consuming pod simply stays in
`CreateContainerConfigError` until it appears. Kubernetes retries automatically.
This is expected and correct -- you don't need Flux-level ordering for it.

## Cluster Entry Points

### `clusters/staging/infrastructure.yaml`

```yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: infra-controllers
  namespace: flux-system
spec:
  interval: 1h
  retryInterval: 1m
  timeout: 5m
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./kubernetes/infrastructure/controllers
  prune: true
  wait: true
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: infra-configs
  namespace: flux-system
spec:
  dependsOn:
    - name: infra-controllers
  interval: 1h
  retryInterval: 1m
  timeout: 5m
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./kubernetes/infrastructure/configs
  prune: true
  wait: true
  patches:
    - patch: |
        - op: replace
          path: /spec/acme/server
          value: https://acme-v02.api.letsencrypt.org/directory
      target:
        kind: ClusterIssuer
        name: letsencrypt
```

### `clusters/staging/observability.yaml`

```yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: obs-controllers
  namespace: flux-system
spec:
  dependsOn:
    - name: infra-configs
  interval: 1h
  retryInterval: 1m
  timeout: 5m
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./kubernetes/observability/controllers
  prune: true
  wait: true
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: obs-configs
  namespace: flux-system
spec:
  dependsOn:
    - name: obs-controllers
  interval: 1h
  retryInterval: 1m
  timeout: 5m
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./kubernetes/observability/configs
  prune: true
  wait: true
```

### `clusters/staging/automation.yaml`

```yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: automation
  namespace: flux-system
spec:
  dependsOn:
    - name: infra-configs
  interval: 1h
  retryInterval: 1m
  timeout: 5m
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./kubernetes/automation
  prune: true
  wait: true
```

### `clusters/staging/apps.yaml`

```yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: apps
  namespace: flux-system
spec:
  dependsOn:
    - name: infra-configs
    - name: automation
  interval: 1h
  retryInterval: 1m
  timeout: 5m
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./kubernetes/apps/staging
  prune: true
  wait: true
```

## Migration Checklist

- [ ] Create `kubernetes/` root directory
- [ ] Consolidate `system/controllers/` and `platform/controllers/` into
  `kubernetes/infrastructure/controllers/`
- [ ] Consolidate `system/configs/` and `platform/configs/` into
  `kubernetes/infrastructure/configs/`
- [ ] Extract monitoring stack into `kubernetes/observability/controllers/`
  and `kubernetes/observability/configs/`
- [ ] Move `deploy/` to `kubernetes/apps/`
- [ ] Move `pre-deploy/` to `kubernetes/automation/`
- [ ] Remove orphaned files: `ingress-nginx.yml`, `rustfs.yml`
- [ ] Remove commented-out `longhorn.yml` (re-add when needed)
- [ ] Update `loki.yaml` API version from `v2beta2` to `v2`
- [ ] Create new cluster entry points in `clusters/staging/`
- [ ] Remove old cluster entry points (`system.yml`, `platform.yml`,
  `pre-deploy.yml`, `deploy.yml`, `infra.yml`)
- [ ] Delete empty `infra/` directory
- [ ] Test with `flux reconcile kustomization flux-system`
- [ ] Add a production overlay under `clusters/production/` when ready

## Adding a New Environment

To add e.g. a `production` cluster:

1. Create `clusters/production/` with the same 4 entry-point files
2. Create `kubernetes/apps/production/` with a Kustomize overlay that patches
   production-specific values (image tags, replicas, hostnames)
3. Use `patches` in the Flux Kustomization to override infrastructure values
   per environment (e.g., Let's Encrypt production vs staging ACME server)
4. Bootstrap Flux pointing to `clusters/production/`

## Adding a New Component

To add a new infrastructure controller (e.g., Longhorn):

1. Create `kubernetes/infrastructure/controllers/longhorn.yaml` with
   Namespace + HelmRepository + HelmRelease
2. Add `longhorn.yaml` to
   `kubernetes/infrastructure/controllers/kustomization.yaml`
3. If it has custom resources, add them to
   `kubernetes/infrastructure/configs/`
4. Commit and push -- Flux handles the rest

No new Flux Kustomizations needed. No dependency chain changes.

To add a new observability component (e.g., Pyroscope):

1. Create `kubernetes/observability/controllers/pyroscope.yaml`
2. Add it to the kustomization
3. If it needs secrets, add the ExternalSecret to
   `kubernetes/infrastructure/configs/external-secrets.yaml` -- it will be
   synced in Phase 2 before observability starts in Phase 3
