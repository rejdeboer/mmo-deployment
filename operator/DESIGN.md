# Realm Operator Design

## Overview

The realm operator manages persistent WoW-style game realms on Kubernetes. Each realm
is composed of multiple zones (e.g. "elwynn-forest", "stormwind"), where each zone is
an independent game server process with its own configuration, resource limits, and
stable network address.

## Coexistence with Agones

Agones remains deployed for **instanced content** (dungeons, battlegrounds, arenas) —
short-lived, session-based game servers that fit Agones' allocate-play-shutdown model.
The realm operator handles **persistent open-world zones**. Both use hostPort networking
but on non-overlapping port ranges:

| System | Port Range | Purpose |
|--------|-----------|---------|
| Agones | 7000-8000 | Instanced content (dungeons, BGs) |
| Realm Operator | 9001+ | Persistent open-world zones |

## Why Not Agones?

Agones is designed for short-lived, session-based game servers (matches, battlegrounds).
This operator is purpose-built for long-lived, named realms where:

- Zones are individually configured (per-zone resources, player caps), not uniform fleet replicas
- Zone servers are persistent processes, not allocate-play-shutdown sessions
- Connection info must be stable and discoverable via a realm list

## Networking: hostPort

Game traffic uses **hostPort** for direct UDP path from the network stack to the container,
bypassing kube-proxy/iptables entirely. This is the same approach Agones uses and is
the standard for latency-sensitive game server networking on Kubernetes.

### Why Not LoadBalancer per Zone?

- Consumes one IP per zone from MetalLB pool (does not scale)
- Adds unnecessary kube-proxy hop for UDP traffic
- No benefit over hostPort for persistent, individually-addressed servers

### Port Assignment

Each zone has a statically assigned `port` in its ZoneSpec. Ports are unique across
the cluster. The realm operator uses ports **9001+** to avoid conflict with Agones'
dynamic port range (default 7000-8000). A convention like `9001-9099` for realm 1,
`9101-9199` for realm 2 keeps things organized, but the operator does not enforce
ranges -- only uniqueness matters.

### Layering Port Stride

When a zone scales to multiple layers, additional layers use ports offset by a stride
of 100 from the base port:

```
stormwind (base port: 7002, maxLayers: 3)
  layer 1 -> hostPort 7002
  layer 2 -> hostPort 7102
  layer 3 -> hostPort 7202
```

This reserves space between zone base ports for layer expansion without conflicts.

## CRDs

### Realm

Represents a single game realm. Defines the pod template and references a ZoneSet.

```yaml
apiVersion: mmo.rejdeboer.com/v1alpha1
kind: Realm
metadata:
  name: stormrage
spec:
  zoneSetRef: azeroth
  template:
    spec:
      containers:
        - name: zone-server
          image: ghcr.io/rejdeboer/zone-server:latest
```

### ZoneSet

Defines the zones that compose a game world. Each zone has a unique name, port,
optional resource overrides, player cap, and max layer count.

```yaml
apiVersion: mmo.rejdeboer.com/v1alpha1
kind: ZoneSet
metadata:
  name: azeroth
spec:
  zones:
    - name: elwynn-forest
      port: 7001
      playerCap: 500
    - name: stormwind
      port: 7002
      playerCap: 2000
      maxLayers: 3
    - name: westfall
      port: 7003
      playerCap: 500
    - name: duskwood
      port: 7004
      playerCap: 300
```

## Architecture

```
Realm CR ──references──> ZoneSet CR
                              |
                    ┌─────────┼─────────┐
                    v         v         v
               Deployment  Deployment  Deployment
               (zone-1)    (zone-2)    (zone-3)
                    |         |         |
                hostPort   hostPort   hostPort
                :7001      :7002      :7003
```

### Reconciliation Loop

For each zone in the referenced ZoneSet, the operator:

1. Creates a single-replica **Deployment** (not a bare Pod) named `{realm}-{zone}`
2. Configures **hostPort** on the game container for direct UDP access
3. Injects env vars: `ZONE_NAME`, `REALM_NAME`, `ZONE_PORT`, `LAYER`, `PLAYER_CAP`
4. Applies per-zone resource overrides to the first container
5. Reports zone status (node IP, port, phase, player count) to Realm CR status
6. Adds a **readiness probe** (`GET /readyz` on port 8080) to gate zone availability — the realm list service should only advertise zones that pass readiness

### Why Deployments Instead of Bare Pods

- **Kubelet auto-restart**: `RestartPolicy: Always` handles crashes without operator intervention
- **Rolling updates**: updating the pod template triggers a controlled rollout
- **Standard tooling**: `kubectl rollout`, monitoring, etc. all work out of the box

### Zone Status

The operator writes per-zone, per-layer status to the Realm CR:

```yaml
status:
  zones:
    - name: stormwind
      layers:
        - layer: 1
          address: 192.168.1.10   # node IP
          port: 7002
          phase: Running
          playerCount: 1247
        - layer: 2
          address: 192.168.1.11
          port: 7102
          phase: Running
          playerCount: 423
```

This status is consumed by the **realm list service** to serve connection info to clients.

## Layering (Zone Instancing)

When a zone's player count approaches its `playerCap`, the operator can create additional
layers -- independent copies of the same zone, each with its own Deployment and hostPort.

- `maxLayers` in ZoneSpec caps how many layers a zone can scale to (default: 1, no layering)
- Layer 1 uses the zone's base port; layer N uses `basePort + (N-1) * 100`
- The realm list service routes new players to the least-loaded layer
- When a layer's player count drops to zero, the operator can remove it

Layering is not yet implemented in the controller. The CRD and status structures are
designed to support it, and the port stride convention is established.

## Player Connection Flow

1. Client requests realm list from the **realm list service** (REST/gRPC, behind Ingress)
2. Service reads Realm CR status, returns zone connection info (`nodeIP:hostPort` per zone/layer)
3. Client connects directly to the zone server via UDP on the given `nodeIP:hostPort`
4. On zone transfer (player walks to a new zone), the current zone server tells the client
   the next zone's `host:port` (read from Realm status or shared config at startup)

## State & Persistence

- **Zone servers are stateless between restarts** -- all player state lives in Postgres (CNPG)
- A zone crash means players reconnect and resume from last DB checkpoint
- The Deployment's restart policy handles the process restart; the DB handles state recovery

## Scaling Considerations

| Concern | Approach |
|---------|----------|
| Zone overload | Layering: operator adds layers when player count nears cap |
| Node failure | Deployment reschedules pod to surviving node. Players reconnect, state is in DB |
| Port exhaustion | ~64k ports per node; even 100 realms x 50 zones = 5000 ports. Not a bottleneck |
| Multi-realm | Each realm is a separate CR with its own ZoneSet. Port ranges don't overlap by convention |
| Image updates | Deployment rolling update, one zone at a time with readiness gates |
| Multi-region | Second cluster with own realm instances. Realm list service returns region-aware list |

## Known Risks & Mitigations

### 1. hostPort Scheduling Conflicts

**Risk**: hostPort binds to a specific port on the node. If the scheduler places two zone
pods that use the same port on the same node, one pod fails to start. This becomes more
likely with layering — e.g. zone A base port 7002 and zone B layer 1 port 7102 are fine,
but two different zones assigned the same port cannot coexist on one node.

**Mitigation**: The operator sets a weighted `podAntiAffinity` rule
(`preferredDuringSchedulingIgnoredDuringExecution`, weight 100) that spreads zone pods
from the same realm across nodes by `kubernetes.io/hostname`. This is preferred (soft)
rather than required (hard) so that pods can still schedule on smaller clusters where
nodes are scarce. For additional safety, port uniqueness should be enforced via a
validation webhook.

### 2. Stale Connection Info During Zone Transfers

**Risk**: When a player walks between zones, the current zone server tells the client the
next zone's `nodeIP:hostPort`. If the target zone was rescheduled to a different node
(crash, rolling update, node drain), the cached address is stale and the client connects
to nothing.

**Mitigation**: Zone servers must read fresh connection info from Realm CR status (or a
shared config endpoint) at transfer time, not cache it at startup. The realm list service
can also serve as the lookup source. Consider having the client resolve the target zone
through the realm list service directly instead of trusting the zone server's redirect.

### 3. Layer Scale-Down Player Experience

**Risk**: The current design removes a layer when player count drops to zero. This is
aggressive — a single remaining player blocks scale-down indefinitely, and abrupt removal
without player migration causes disconnects.

**Mitigation**: Implement hysteresis: scale down when a layer is below a threshold (e.g.
10% of playerCap) for a sustained cooldown period (e.g. 5 minutes). Before removing a
layer, mark it as draining (stop routing new players to it via realm list service) and
optionally notify connected players to transfer to another layer. Only terminate the pod
after drain completes or a grace period expires.

### 4. Player Count Reporting Mechanism

**Risk**: The operator needs real-time player counts for layering decisions, but the
reporting mechanism is unspecified. Each option has trade-offs:
- Zone servers writing to the CRD requires RBAC and handles conflict retries
- Operator scraping a metrics endpoint requires pod-IP-based discovery
- A push-based gRPC call from zone to operator adds coupling

**Mitigation**: Prefer the operator scraping a simple HTTP endpoint on each zone pod
(e.g. `GET /status` returning JSON with player count). The operator already knows pod IPs
from the Deployment status. This avoids giving zone servers write access to CRDs and
keeps the data flow unidirectional. Poll interval of 10-15 seconds is sufficient for
layering decisions.

### 5. Rolling Updates Disconnect Players

**Risk**: A Deployment rolling update kills the running zone pod. All players connected
to that zone are disconnected with no warning. For a persistent MMO zone, this is a poor
experience compared to session-based games where matches end naturally.

**Mitigation**: Implement graceful drain in the zone server:
1. `preStop` hook signals the zone server to stop accepting new players
2. Zone server notifies connected clients to reconnect (with a countdown or after save)
3. Zone server flushes all player state to the database
4. Pod terminates after drain completes or `terminationGracePeriodSeconds` expires

The operator sets `terminationGracePeriodSeconds` to 120 seconds on all zone pods,
giving zone servers enough time to drain. The `preStop` hook itself must be implemented
in the zone server image. For planned updates, consider a custom rollout strategy: drain
zone A, update it, wait for it to become ready, then proceed to zone B.

### 6. Realm List Service Availability

**Risk**: The realm list service is the single entry point for all new player connections.
If it is unavailable, no new players can connect (existing connections are unaffected).

**Mitigation**: The service is stateless (reads from Kubernetes API / Realm CR status),
so it scales horizontally with a standard Deployment + Service. Run at least 2 replicas
with pod anti-affinity. Consider caching Realm status with a watch rather than polling
to reduce API server load and improve response latency.

### 7. Port Stride Limits

**Risk**: The layer port stride of 100 imposes implicit limits: max ~100 zones per realm
(within a 100-port range) and max 100 layers per zone. Exceeding these causes port
collisions that may not be obvious.

**Mitigation**: These limits are generous for practical use (100 layers would mean a zone
handling 50k+ players assuming a 500 playerCap). Document the limits explicitly and
enforce them in the validation webhook. If higher zone counts are needed, increase the
stride or switch to dynamic port allocation from a managed pool.
