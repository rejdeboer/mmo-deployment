provider "flux" {
  kubernetes = {
    config_path = local.kubeconfig_path
  }
  git = {
    url    = "ssh://git@github.com/${local.github_owner}/${local.github_repository}.git"
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
  components_extra = [
    "image-reflector-controller",
    "image-automation-controller"
  ]
  kustomization_override = <<-EOT
    apiVersion: kustomize.config.k8s.io/v1beta1
    kind: Kustomization
    resources:
      - gotk-components.yaml
      - gotk-sync.yaml
    patches:
      - target:
          kind: Namespace
          name: flux-system
        patch: |
          - op: add
            path: /metadata/labels/inject-registry-credentials
            value: "true"
  EOT
}

