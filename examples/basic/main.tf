module "talos_cluster" {
  source = "../.."

  proxmox_target_node    = "your-proxmox-node"
  proxmox_storage_device = "local-lvm"

  cluster_name          = "your-cluster-name"
  cluster_vip_shared_ip = "192.168.10.100"

  network             = "192.168.10.0/24"
  network_gateway     = "192.168.10.1"
  domain_name_servers = ["192.168.10.1"]

  node_data = {
    controlplanes = {
      "192.168.10.101" = {
        install_disk  = "/dev/vda"
        install_image = "factory.talos.dev/nocloud-installer/ce4c980550dd2ab1b17bbf2b08801c7eb59418eafe8f279833297925d67c7515:v1.13.8"
        hostname      = "your-cluster-name-cp-0"
      }
    }
    workers = {
      "192.168.10.102" = {
        install_disk  = "/dev/vda"
        install_image = "factory.talos.dev/nocloud-installer/ce4c980550dd2ab1b17bbf2b08801c7eb59418eafe8f279833297925d67c7515:v1.13.8"
        hostname      = "your-cluster-name-worker-0"
      }
    }
  }
}
