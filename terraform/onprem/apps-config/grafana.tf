
ephemeral "vault_kv_secret_v2" "grafana" {
  mount = var.vault_mount_path
  name  = "infrastructure/grafana-admin"
}

provider "grafana" {
  url  = "https://grafana.${local.domain}"
  auth = "${ephemeral.vault_kv_secret_v2.grafana.data["admin_user"]}:${ephemeral.vault_kv_secret_v2.grafana.data["admin_password"]}"
}

resource "grafana_apps_provisioning_repository_v0alpha1" "sync" {
  metadata {
    uid = "dashboards"
  }

  spec {
    title       = "Game dashboards"
    description = "Game dashboards"
    type        = "github"

    workflows = ["write", "branch"]

    sync {
      enabled          = true
      target           = "folderless"
      interval_seconds = 60
    }

    github {
      url    = "https://github.com/${local.github_org}/${local.github_deployment_repository}"
      branch = "main"
      path   = "kubernetes/platform/observability/dashboards"
    }

    webhook {
      base_url = "https://grafana.${local.domain}"
    }
  }

  secure {
    token = {
      create = ephemeral.vault_kv_secret_v2.github.data["pat"]
    }
  }
  secure_version = 1
}
