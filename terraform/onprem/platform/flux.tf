provider "flux" {
  kubernetes = {
    config_path = local.kubeconfig_path
  }
  git = {
    url    = "ssh://git@github.com/${local.github_org}/${local.github_repository}.git"
    branch = local.github_branch
    ssh = {
      username    = "git"
      private_key = tls_private_key.flux.private_key_pem
    }
  }
}

resource "flux_bootstrap_git" "this" {
  depends_on = [
    github_repository_deploy_key.this
  ]
  path = "clusters/staging"
}

