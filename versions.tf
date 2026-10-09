# Providers are configured by the calling root module, see examples/.
# The ephemeral talos_cluster_kubeconfig resource and the write-only kubeconfig_wo
# attribute of talos_machine require OpenTofu >= 1.11.
terraform {
  required_version = ">= 1.11.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.111.1, < 1.0.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.12.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.2"
    }
  }
}
