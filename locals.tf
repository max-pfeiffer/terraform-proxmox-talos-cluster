locals {
  cluster_endpoint = "https://${var.cluster_vip_shared_ip}:6443"

  # Prefix length of the node network, used for the node IP addresses
  network_prefix_length = split("/", var.network)[1]

  # Proxmox node per Talos node, falling back to proxmox_target_node
  controlplane_proxmox_nodes = { for ip, node in var.node_data.controlplanes : ip => coalesce(node.proxmox_node, var.proxmox_target_node) }
  worker_proxmox_nodes       = { for ip, node in var.node_data.workers : ip => coalesce(node.proxmox_node, var.proxmox_target_node) }

  # The Talos ISO image is downloaded to every Proxmox node which hosts a virtual machine
  proxmox_nodes = toset(concat(values(local.controlplane_proxmox_nodes), values(local.worker_proxmox_nodes)))

  # Manifests applied by Talos on bootstrap, the order is preserved
  inline_manifests = concat(
    var.gateway_api_crds_enabled ? [
      {
        name     = "gateway-api"
        contents = file("${path.module}/gateway-api/gateway-api-crds-v1.6.1.yaml")
      },
    ] : [],
    [
      {
        name     = "cilium"
        contents = data.helm_template.cilium.manifest
      },
    ],
    var.extra_inline_manifests,
  )
}
