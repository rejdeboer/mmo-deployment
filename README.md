# MMORPG Kubernetes deployment (Work in progress)

This repository contains all the Kubernetes manifests and Terraform configuration required to deploy the backend infrastructure for our Rust-based MMO project. It uses a modern, cloud-native architecture designed for scalability, reliability, and cost-efficiency, even when deployed in a homelab environment.

## Architectural Philosophy

This project follows a **hybrid architecture** that combines the stability of traditional persistent-world servers with the elasticity of modern, cloud-native session-based servers.

*   **Persistent Worlds (StatefulSets):** Core, long-running game worlds (e.g., continents, "realms") are managed as Kubernetes `StatefulSets`. This provides them with stable network identities and persistent storage, which is crucial for a classic MMO feel where the world feels permanent and always-on.
*   **Instanced Content (Agones):** On-demand, session-based content like dungeons, raids, or battlegrounds will be managed by [Agones](https://agones.dev/). This allows us to dynamically scale resources up and down based on player demand, saving significant cost and resources. (Note: Currently planned, not yet implemented).
*   **Web Server as Connect Broker:** The web server is the single entry point for players. It handles authentication and, critically, acts as a "connect broker." It queries the Kubernetes API to discover the correct game server address and generates a time-limited `netcode.io` connect token, ensuring secure and managed connections.

## Core Technologies

*   **Container Orchestration:** [Kubernetes (K8s)](https://kubernetes.io/)
*   **Game Server Orchestration:** Agones for managing the lifecycle of session-based game servers, handling dynamic allocation, and enabling elastic scaling.
*   **Ingress & Networking:** [Traefik](https://traefik.io/traefik/) as our Ingress Controller (using `IngressRoute` CRDs) and [MetalLB](https://metallb.universe.tf/) for exposing services in a bare-metal/homelab environment.
*   **TLS Certificates (WIP):** [cert-manager](https://cert-manager.io/) with Let's Encrypt for automatic HTTPS.
*   **Observability:** [Prometheus](https://prometheus.io/) for metrics, [Loki](https://grafana.com/oss/loki/) for structured logging, and [Grafana](https://grafana.com/oss/grafana/) for visualization.
*   **Database:** PostgreSQL, managed by the [CloudNativePG (CNPG)](https://cloudnative-pg.io/) operator for high availability.
*   **DNS:** Pi-hole for local network DNS resolution, automatically updated by ExternalDNS. This allows us to use friendly hostnames (e.g., mmo.homelab.io) that resolve correctly within the local network.
*   **Secret Management:** Sealed Secrets for safely storing secrets (like API keys and database passwords) in a public Git repository. Secrets are encrypted locally and can only be decrypted by the Sealed Secrets controller running in the cluster.

