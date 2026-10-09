[![OpenTofu](https://img.shields.io/badge/OpenTofu-FFDA18?logo=opentofu&logoColor=black)](https://opentofu.org/)
[![Code quality](https://github.com/max-pfeiffer/terraform-proxmox-talos-cluster/actions/workflows/code-quality.yaml/badge.svg)](https://github.com/max-pfeiffer/terraform-proxmox-talos-cluster/actions/workflows/code-quality.yaml)
[![Release](https://github.com/max-pfeiffer/terraform-proxmox-talos-cluster/actions/workflows/release.yaml/badge.svg)](https://github.com/max-pfeiffer/terraform-proxmox-talos-cluster/actions/workflows/release.yaml)

# Proxmox Talos OpenTofu Module
An [OpenTofu](https://opentofu.org/) module which provisions a turnkey Kubernetes cluster with
[Talos Linux](https://www.talos.dev/) on a
[Proxmox VE hypervisor](https://www.proxmox.com/en/products/proxmox-virtual-environment/overview).

Kubernetes cluster features:
* [Talos Linux v1.13.8](https://www.talos.dev/)
* Kubernetes v1.36.3
* no kube-proxy
* [Cilium v1.20.0](https://cilium.io/) as Container Network Interface (CNI)
  * without kube-proxy
  * with [L2 loadbalancer support](https://docs.cilium.io/en/stable/network/l2-announcements/)
  * with [Ingress controller support](https://docs.cilium.io/en/stable/network/servicemesh/ingress/) (optional)
  * with [Gateway API support](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/)
  * with [Egress gateway support](https://docs.cilium.io/en/stable/network/egress-gateway/egress-gateway/)
* [Gateway API v1.6.1](https://gateway-api.sigs.k8s.io/) CRDs (standard channel) are installed (optional)
* control plane nodes share a [virtual IP](https://www.talos.dev/v1.13/talos-guides/network/vip/) as Kubernetes API endpoint
* Talos OS and Kubernetes upgrades are handled declaratively, see [Upgrading](#upgrading)

The module creates one virtual machine per node, downloads the Talos Linux ISO image to every Proxmox node which hosts
a virtual machine, applies the Talos machine configuration, bootstraps the cluster and returns `kubeconfig` and
`talosconfig`.

## Requirements
* [OpenTofu](https://opentofu.org/) >= 1.11.0
* A Proxmox VE API token with permissions to manage virtual machines, storage and downloads
* A Talos Linux image with the [QEMU guest agent extension](https://github.com/siderolabs/extensions/tree/main/guest-agents/qemu-guest-agent),
  build one with the [Talos Linux Image Factory](https://factory.talos.dev/) (platform `nocloud`)

## Usage
The module does not configure any providers. Configure the [bpg/proxmox](https://registry.terraform.io/providers/bpg/proxmox/latest/docs)
provider in your root module, the `siderolabs/talos` and `hashicorp/helm` providers need no configuration:
```hcl
provider "proxmox" {
  endpoint  = "https://192.168.1.25:8006/"
  api_token = "${var.proxmox_api_token_id}=${var.proxmox_api_token_secret}"
  insecure  = true
}

module "talos_cluster" {
  source = "git::https://github.com/max-pfeiffer/terraform-proxmox-talos-cluster.git?ref=v0.1.0" # x-release-please-version

  proxmox_target_node    = "your-proxmox-node"
  proxmox_storage_device = "local-lvm"

  talos_version      = "1.13.8"
  kubernetes_version = "1.36.3"

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

output "kubeconfig" {
  value     = module.talos_cluster.kubeconfig
  sensitive = true
}
```
Nodes in `node_data` are keyed by their IPv4 address. `hostname`, `cpu_cores`, `memory` (MB), `disk_size` (GB) and
`proxmox_node` are optional per node. Without a `hostname` Talos Linux generates one itself, without a `proxmox_node`
the virtual machine is created on `proxmox_target_node`.

Complete examples are in the [examples](examples) directory:
* [basic](examples/basic): one control plane and one worker node
* [advanced](examples/advanced): highly available control plane spread across a Proxmox cluster, VLAN, config
  patches for registry mirrors and additional Cilium Helm values

Apply the configuration and grab the kube config file:
```shell
$ tofu init
$ tofu apply
$ tofu output -raw kubeconfig > ~/.kube/config
$ chmod 600 ~/.kube/config
$ kubectl get nodes
NAME                          STATUS   ROLES           AGE   VERSION
your-cluster-name-cp-0        Ready    control-plane   5d    v1.36.3
your-cluster-name-worker-0    Ready    <none>          5d    v1.36.3
```
You might need to wait a bit until the nodes come up.

## Inputs
| Name | Description | Type | Default |
|------|-------------|------|---------|
| `proxmox_target_node` | Proxmox VE node the virtual machines are created on, can be overridden per node | `string` | required |
| `proxmox_storage_device` | Proxmox datastore for the virtual machine disks and cloud-init drives | `string` | required |
| `proxmox_iso_datastore` | Proxmox datastore the Talos Linux ISO image is downloaded to | `string` | `"local"` |
| `proxmox_network_bridge` | Proxmox network bridge the virtual machines are attached to | `string` | `"vmbr0"` |
| `vm_cpu_type` | CPU type emulated for the virtual machines | `string` | `"host"` |
| `talos_version` | Talos machine configuration contract version, see [Upgrading Talos](#upgrading-talos) | `string` | required |
| `kubernetes_version` | Kubernetes version of the cluster, see [Upgrading Kubernetes](#upgrading-kubernetes) | `string` | required |
| `talos_linux_iso_image_url` | URL of the Talos ISO image for initially booting the VMs | `string` | Image Factory URL for v1.13.8 with QEMU guest agent |
| `talos_linux_iso_image_filename` | Filename of the Talos ISO image on Proxmox | `string` | `"talos-linux-v1.13.8-qemu-guest-agent-amd64.iso"` |
| `cluster_name` | Name of the Talos cluster, also used as prefix for the VM names | `string` | `"talos"` |
| `cluster_vip_shared_ip` | Shared virtual IP of the control plane nodes, used as Kubernetes API endpoint | `string` | required |
| `node_data` | Control plane and worker nodes keyed by IPv4 address, see [Usage](#usage) | `object` | required |
| `network` | Network for all nodes in CIDR notation, its prefix length is used for the node IPs | `string` | required |
| `network_gateway` | Network gateway for all nodes | `string` | required |
| `domain_name_servers` | DNS servers for all nodes | `list(string)` | required |
| `vlan_tag` | VLAN tag for all nodes, `0` does not configure a VLAN | `number` | `0` |
| `allow_scheduling_on_control_planes` | Allows scheduling workloads on control plane nodes | `bool` | `false` |
| `talos_machine_config_patch_controlplane` | Configuration patch applied to all control plane nodes | `string` | `""` |
| `talos_machine_config_patch_worker` | Configuration patch applied to all worker nodes | `string` | `""` |
| `extra_inline_manifests` | Additional manifests applied by Talos on bootstrap (`name`, `contents`) | `list(object)` | `[]` |
| `gateway_api_crds_enabled` | Installs the Gateway API v1.6.1 CRDs on bootstrap | `bool` | `true` |
| `cilium_version` | Version of the Cilium Helm chart | `string` | `"1.20.0"` |
| `ingress_controller_enabled` | Enables the Cilium Ingress controller | `bool` | `true` |
| `cilium_helm_set` | Additional Cilium Helm values (`name`, `value`, optional `type`), they override the module's defaults | `list(object)` | `[]` |
| `cilium_helm_values` | Additional Cilium Helm values as YAML documents | `list(string)` | `[]` |

## Outputs
| Name | Description |
|------|-------------|
| `kubeconfig` | Kubeconfig for cluster administration (sensitive) |
| `talosconfig` | Talos client configuration for `talosctl` (sensitive) |
| `kubernetes_client_configuration` | Kubernetes API host and client credentials, e.g. for configuring the `kubernetes` and `helm` providers (sensitive) |
| `client_configuration` | Talos client CA certificate, certificate and key (sensitive) |
| `machine_secrets` | Talos machine secrets, keep them safe for disaster recovery (sensitive) |
| `cluster_name` | Name of the Talos cluster |
| `cluster_endpoint` | Kubernetes API endpoint |
| `controlplane_ips` | IP addresses of the control plane nodes |
| `worker_ips` | IP addresses of the worker nodes |
| `controlplane_vm_ids` | Proxmox VM IDs of the control plane nodes, keyed by IP address |
| `worker_vm_ids` | Proxmox VM IDs of the worker nodes, keyed by IP address |

## Upgrading
Talos OS and Kubernetes versions are managed declaratively through the
[terraform-provider-talos](https://github.com/siderolabs/terraform-provider-talos) v0.12.0 resources:

* `talos_machine` owns each node's machine configuration and its Talos OS version. On every
  `tofu plan`/`apply` the provider reads the running Talos version, the active Image Factory
  schematic and the applied machine configuration hash from the node and reconciles any drift.
* `talos_cluster` bootstraps etcd and owns the Kubernetes version. Changing its `kubernetes_version`
  runs Talos' `upgrade-k8s` procedure, which pre-pulls images and upgrades kube-apiserver,
  kube-controller-manager, kube-scheduler, kube-proxy and the kubelets sequentially with health
  gating.

Gracefully orchestrating in-place upgrades through Terraform/OpenTofu has long been a rough edge in
the Talos provider — see [siderolabs/terraform-provider-talos#140](https://github.com/siderolabs/terraform-provider-talos/issues/140)
for the multi-year discussion on graceful, node-by-node upgrades.

### Upgrading Talos
1. Pick the new Talos version and update `talos_linux_iso_image_url` and
   `talos_linux_iso_image_filename`.
2. For every node in `node_data`, update `install_image` to the matching version tag, e.g.
   `factory.talos.dev/nocloud-installer/<schematic-id>:v1.14.0`. The schematic ID stays the same
   across versions unless you change the extensions baked into the image on the
   [Talos Image Factory](https://factory.talos.dev/); only the version tag needs bumping.
   `install_image` alone drives the OS upgrade.
3. Leave `talos_version` alone. It is the *machine configuration contract*, pinned to the version the
   cluster was created with, and is independent of the installed Talos version — the provider's docs
   make this [explicit](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/data-sources/machine_configuration)
   as of v0.12.0. Bumping it regenerates every node's machine configuration with the new contract's
   schema and defaults, which is a separate, deliberate action, not part of a routine OS upgrade.
4. Run `tofu plan` to confirm only the `image` field (and any machine config drift) is changing, not
   disk layout or network settings.
5. Control plane and worker nodes are each applied with `for_each` and have no `depends_on` chaining
   between individual nodes, so a plain `tofu apply` upgrades every node in parallel. For a
   multi-control-plane cluster this risks losing etcd quorum. Run `tofu apply -parallelism=1` instead
   to upgrade nodes one at a time — see the provider's
   [Upgrading multiple nodes safely](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/machine#upgrading-multiple-nodes-safely)
   guidance.
6. `drain_on_upgrade` is `true` for all `talos_machine` resources, so each node is cordoned and
   drained before it reboots and uncordoned afterwards. The kubeconfig needed for that is derived
   offline from the machine secrets by an ephemeral `talos_cluster_kubeconfig` resource, which keeps it
   free of a dependency cycle with `talos_machine` and out of the state. Draining requires a healthy
   Kubernetes cluster, so keep the ISO version and `install_image` in step (1)/(2) in sync: an upgrade
   that fires during the *initial* bring-up, before Kubernetes exists, would fail on the drain.

### Upgrading Kubernetes
1. Update `kubernetes_version`.
2. The value feeds both `talos_cluster` and the generated machine configuration. `talos_cluster`
   performs the actual rolling upgrade via `upgrade-k8s`; the machine configuration only controls the
   image tags baked into it, which matter at bootstrap when a node is added later, so the two must stay
   in sync — a single variable feeds both.
3. All `talos_machine` resources set `ignore_kubernetes_upgrade_drift = true`, so the five
   Kubernetes component image fields owned by `upgrade-k8s` (`machine.kubelet.image`,
   `cluster.apiServer.image`, `cluster.controllerManager.image`, `cluster.scheduler.image`,
   `cluster.proxy.image`) are excluded from `talos_machine`'s drift detection. Without it,
   `tofu apply` would re-apply those tags directly and in parallel across all nodes, bypassing
   `upgrade-k8s`'s sequencing. Note that the attribute is flagged experimental by the provider: only
   the version tag is stripped from the hash, so a registry change is still detected as drift.
4. A plain `tofu apply` is safe here — `talos_cluster` does the sequencing and health gating itself,
   so `-parallelism=1` is not needed for this step.

## Versioning
The module follows [Semantic Versioning](https://semver.org/), releases are tagged `vX.Y.Z` and created by
[release-please](https://github.com/googleapis/release-please) from [Conventional Commits](https://www.conventionalcommits.org/).
While the module is below `1.0.0`, breaking changes bump the minor version and everything else the patch version.
Pin the module to an exact tag with `?ref=` and read the [changelog](CHANGELOG.md) before upgrading.

A change is breaking (`feat!:` or a `BREAKING CHANGE:` footer) if it changes infrastructure that existing users get
on their next `tofu apply` without touching their configuration, in particular:
* changing the default of any version input, e.g. `cilium_version`, `talos_linux_iso_image_url` or the bundled
  Gateway API CRDs
* removing or renaming inputs or outputs, adding required inputs or changing their types
* changing resource addresses without `moved` blocks
* raising the minimum OpenTofu or provider versions

## Development
[Install uv](https://docs.astral.sh/uv/getting-started/installation/) and sync dependencies:
```shell
uv sync
```
Install git hooks:
```shell
pre-commit install --hook-type commit-msg --hook-type pre-commit --hook-type pre-push
```
Commit messages and pull request titles must follow [Conventional Commits](https://www.conventionalcommits.org/),
both are checked in CI. Pull requests are squash merged with their title as commit message.
Validate the module and the examples:
```shell
tofu init -backend=false && tofu validate
```

## Information Sources
* [Talos Linux documentation](https://www.talos.dev/)
* [Talos Linux Image Factory](https://factory.talos.dev/)
* [Cilium documentation](https://docs.cilium.io/en/stable/)
* [Gateway API](https://gateway-api.sigs.k8s.io/)
* Terraform providers:
  * [terraform-provider-proxmox](https://github.com/bpg/terraform-provider-proxmox)
  * [terraform-provider-talos](https://github.com/siderolabs/terraform-provider-talos)
  * [terraform-provider-helm](https://github.com/hashicorp/terraform-provider-helm)
* Helm charts:
  * [Cilium](https://artifacthub.io/packages/helm/cilium/cilium)
