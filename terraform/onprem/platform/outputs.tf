output "vault_mount_path" {
  description = "Vault secret mount path"
  value       = vault_mount.kv.path
}
