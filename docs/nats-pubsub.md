# NATS for Web Server Pub/Sub

## Context

The web server handles social features (chat, party invites) over WebSocket connections. With a single replica, all connected users share the same process, so delivering messages between them is trivial.

In production, we need multiple web server replicas for availability and load distribution. However, when user A is connected to pod 1 and user B to pod 2, there is no built-in mechanism for cross-pod message delivery.

## Decision

Deploy NATS as a lightweight pub/sub message broker. Web server pods publish events (chat messages, invites) to NATS subjects and subscribe to subjects relevant to their connected users. This allows any pod to deliver messages to any online user regardless of which pod they're connected to.

### Why NATS

- Purpose-built for low-latency pub/sub
- Minimal operational overhead (single binary, small footprint)
- Subject-based routing maps naturally to the domain (e.g., `chat.<room_id>`, `invite.<user_id>`)
- Common in game server architectures

### Why not JetStream / persistence

Invites and chat only matter for online users. If a user is offline, there is no WebSocket to deliver to. Offline features (e.g., in-game mail) would be implemented via database writes and checked on login, not via NATS.

### Alternatives considered

- **Redis Pub/Sub**: Viable but adds Redis as a dependency we don't otherwise need
- **Kafka**: Overkill for real-time ephemeral messaging
- **Direct gRPC between pods**: Requires service discovery, doesn't scale cleanly

## Implementation

1. **Namespace**: `nats` added to `system/configs/namespaces.yml`
2. **Deployment**: HelmRelease in `platform/controllers/nats.yml` (NATS chart v1.2.12, single node, no JetStream)
3. **Web server**: Replicas increased to 2, `APP_NATS__URL` env var added pointing to `nats://nats.nats.svc.cluster.local:4222`

## Suggested subject patterns

| Feature | Subject | Publisher | Subscriber |
|---------|---------|-----------|------------|
| Chat | `chat.<room_id>` | Pod receiving the message | All pods with users in that room |
| Invite | `invite.<user_id>` | Pod sending the invite | Pod where target user is connected |

## Future considerations

- Scale NATS to 3-node cluster if the single node becomes a bottleneck or SPOF
- Enable JetStream if durable messaging is needed later (e.g., in-game mail)
- Add NetworkPolicy restricting NATS access to only the web-server pods
