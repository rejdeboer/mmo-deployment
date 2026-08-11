## Storage
- Switch CNPG from `local-path` to Longhorn for snapshots and backup-to-S3
- Enable CNPG WAL backups to S3 (player data, non-negotiable)
- Switch Zot registry PVC to Longhorn (currently local-path, won't work multi-node)
- Remove RustFS (was POC, no longer needed)
- Remove Garage VM from Terraform and cloud-init (was POC for MinIO replacement)
- Consider replacing MinIO with a lighter alternative (e.g. Garage) in the future

## Security
- Enable Vault TLS (currently `tls_disable = "true"`, secrets sent in plaintext)
- Replace hardcoded Vault IP (`192.168.1.52`) in ClusterSecretStore with DNS

## Bug Fixes
- Fix cloud-init hostname: all VMs have hostname set to `host2` (copy-paste bug)
- Fix Loki config: schemaConfig says `filesystem` but S3 is configured, `singleBinary.replicas: 0` means no pods running

## Infrastructure
- Allocate more MetalLB IPs (currently single /32 at 192.168.1.200)

## Realm Operator

The realm operator (`operator/`) manages persistent WoW-style game realms. Unlike Agones,
which is designed for short-lived session-based game servers (matches, battlegrounds), this
operator is purpose-built for long-lived, named realms where each zone is an independent
process with its own configuration, resource limits, and stable network address.

See `operator/DESIGN.md` for full architecture documentation.

Key design decisions:
- **hostPort** for game traffic (direct UDP, no kube-proxy overhead) instead of LoadBalancer per zone
- **Single-replica Deployments** per zone instead of bare Pods (kubelet restarts, rolling updates)
- **Per-zone port assignment** in ZoneSpec with stride-based layering support
- **Layering** (zone instancing) supported in CRD design with `maxLayers` field
- Zone connection info (nodeIP:hostPort) written to Realm CRD status for realm list discovery

### Done
- [x] Realm and ZoneSet CRDs with per-zone config (resources, playerCap, port, maxLayers)
- [x] Single-replica Deployment per zone with hostPort networking
- [x] Per-zone/per-layer status reporting (node address, hostPort, phase, playerCount)
- [x] Ready condition on Realm status
- [x] ZoneSet watch — changes to a ZoneSet trigger Realm reconciliation
- [x] Orphan cleanup — removed zones get their Deployments deleted
- [x] Zone-specific env var injection (ZONE_NAME, REALM_NAME, ZONE_PORT, LAYER, PLAYER_CAP)
- [x] Crash recovery via Deployment restart policy (kubelet handles restarts)
- [x] Image update rollout via Deployment rolling updates

### Remaining
- [ ] Layering implementation: operator creates additional layers when player count nears
      playerCap, using port stride of 100 per layer. CRD and status structures are ready.
- [ ] Graceful shutdown: add `preStop` lifecycle hook so zone servers can flush player
      state to DB before pod termination. Consider a finalizer with grace period for
      zone removal from ZoneSet.
- [ ] Realm list service: build a service that reads Realm CRD status and serves a
      realm list to game clients (realm name, zone addresses, player counts, status).
- [ ] Player count reporting: zone servers need to expose current player count (e.g. via
      metrics endpoint or gRPC) so the operator can write it to status.
- [ ] Operator-level metrics: expose Prometheus metrics for zone count, realm health,
      reconcile latency, error rates.
- [ ] Validation webhook: reject invalid Realm/ZoneSet specs (duplicate zone names,
      duplicate ports, invalid resource values).
- [ ] E2E tests: add tests for zone creation, orphan cleanup, ZoneSet updates, and
      layering.

## Game Server Infrastructure
- Build a simple matchmaking service with player session routing
- Build a synthetic player load testing tool to simulate concurrent connections
- Add game-specific observability (tick rate, player latency histograms, CCU dashboards)

## Reliability & Operations
- Set up chaos engineering (Chaos Mesh) for failure injection and resilience testing
- Implement progressive delivery with Flagger for canary deployments

## Multi-Region (Simulated)
- Set up a second k3s cluster (cheap VPS) to practice multi-cluster federation and failover
- Document design decisions as if operating at scale (capacity planning, failover strategy)
