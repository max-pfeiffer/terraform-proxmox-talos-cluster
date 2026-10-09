resource "proxmox_download_file" "talos_linux_iso_image" {
  for_each            = local.proxmox_nodes
  content_type        = "iso"
  datastore_id        = var.proxmox_iso_datastore
  node_name           = each.key
  url                 = var.talos_linux_iso_image_url
  file_name           = var.talos_linux_iso_image_filename
  overwrite_unmanaged = true
}
