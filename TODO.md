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
