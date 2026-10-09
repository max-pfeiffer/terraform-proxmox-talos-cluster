variable "proxmox_api_url" {
  description = "URL of the Proxmox VE API, e.g. https://192.168.1.25:8006/"
  type        = string
}

variable "proxmox_api_token_id" {
  description = "Proxmox API token ID, e.g. root@pam!opentofu"
  type        = string
  sensitive   = true
}

variable "proxmox_api_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Skips TLS verification of the Proxmox API, e.g. for self-signed certificates"
  type        = bool
  default     = true
}
