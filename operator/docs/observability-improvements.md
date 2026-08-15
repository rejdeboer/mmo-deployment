## App/Infra Recommendations  

### Labeling consistency  
- One pod (`game-server-57g4m-ghdc6`, `job="game-server-metrics"`) doesn't follow the  
  `main-` naming/job convention the others use (`job="main-zone-metrics"`).  
  Check whether it's missing the ServiceMonitor's relabel rules or is a legacy  
  singleton — if it's a real realm/zone, give it matching `realm`/`zone`/`layer`  
  labels; if it's a leftover, consider retiring it.  
- `layer` currently only has one value (`1`) across all pods. Confirm this is  
  intentional (e.g. reserved for future PvP/instance tiers) — an always-constant  
  label adds cardinality with no query value.  

### Metric/label gaps  
- `game_network_bytes_total` / `game_network_packets_total` are per-`channel`.  
  Verify `sum by (channel, realm, zone)` cardinality stays reasonable  
  (channels × zones × realms) as realm count grows.  
- Loki streams for `game-server` only carry Kubernetes-native labels  
  (`pod`, `container`, `namespace`, ...) — **no `realm`/`zone`/`layer`**.  
  Add these as structured metadata or Promtail/Alloy relabeled stream labels  
  from the pod labels, so Loki and Prometheus share the same source of truth.  

### Cardinality / ops hygiene  
- Key alerting and recording rules off `realm`/`zone`/`layer` (e.g. tick-rate  
  alerts per zone, not per pod) so they survive pod rescheduling.  
- If realm count grows into the dozens+, add recording rules pre-aggregating  
  `sum by (realm, zone)` for heavy panels (Connected Players, Tick Rate) to  
  keep dashboard queries cheap.  

### Pod naming  
- Standardize pod name patterns across realms (`main--`) now that  
  labels carry the semantic meaning, so nothing has to parse names again.  
