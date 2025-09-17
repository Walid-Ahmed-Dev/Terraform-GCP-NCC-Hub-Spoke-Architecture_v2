terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# Provider configuration
provider "google" {
  project     = var.ncc_project_id
  region      = var.ncc_region
  credentials = file(var.ncc_credentials_path)
  alias       = "ncc_hub"
}

# NCC hub VPC
resource "google_compute_network" "ncc_vpc" {
  provider                = google.ncc_hub
  name                    = "${var.prefix}-ncc-vpc"
  project                 = var.ncc_project_id
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

# NCC hub subnet
resource "google_compute_subnetwork" "ncc_subnet" {
  provider                 = google.ncc_hub
  name                     = "${var.prefix}-ncc-subnet"
  project                  = var.ncc_project_id
  region                   = var.ncc_region
  network                  = google_compute_network.ncc_vpc.self_link
  ip_cidr_range            = var.ncc_subnet_cidr
  private_ip_google_access = false
}

# NCC hub HA VPN Gateway
resource "google_compute_ha_vpn_gateway" "ncc_vpn_gateway" {
  provider = google.ncc_hub
  name     = "${var.prefix}-ncc-vpn-gateway"
  project  = var.ncc_project_id
  region   = var.ncc_region
  network  = google_compute_network.ncc_vpc.self_link
}

# NCC hub Cloud Router
resource "google_compute_router" "ncc_cloud_router" {
  provider = google.ncc_hub
  name     = "${var.prefix}-ncc-cloud-router"
  project  = var.ncc_project_id
  region   = var.ncc_region
  network  = google_compute_network.ncc_vpc.self_link
  bgp {
    asn = var.ncc_asn
  }
}

# NCC hub
resource "google_network_connectivity_hub" "ncc_hub" {
  provider = google.ncc_hub
  name     = "${var.prefix}-ncc-hub"
  project  = var.ncc_project_id
}

# Allow spoke SA to read statefile and use lock files 
resource "google_storage_bucket_iam_member" "spoke_state_admin" {
  for_each = { for spoke in var.spoke_configs : spoke.name => spoke }
  provider = google.ncc_hub
  bucket   = var.ncc-hub_statefile_bucket_name
  role     = "roles/storage.objectAdmin"
  member   = "serviceAccount:${each.value.service_account}"
}

# Hub service account IAM roles
resource "google_project_iam_member" "hub_network_admin" {
  provider = google.ncc_hub
  project  = var.ncc_project_id
  role     = "roles/compute.networkAdmin"
  member   = "serviceAccount:${var.ncc_hub_service_account}"
}

resource "google_project_iam_member" "hub_ncc_admin" {
  provider = google.ncc_hub
  project  = var.ncc_project_id
  role     = "roles/networkconnectivity.hubAdmin"
  member   = "serviceAccount:${var.ncc_hub_service_account}"
}

# Spoke service account IAM roles
resource "google_project_iam_member" "spoke_network_user" {
  for_each = { for spoke in var.spoke_configs : spoke.name => spoke }
  provider = google.ncc_hub
  project  = var.ncc_project_id
  role     = "roles/compute.networkUser"
  member   = "serviceAccount:${each.value.service_account}"
}

# Grant roles/networkconnectivity.spokeAdmin to spoke service accounts in the hub project
resource "google_project_iam_member" "spoke_connectivity_spoke_admin" {
  for_each = { for spoke in var.spoke_configs : spoke.name => spoke }
  provider = google.ncc_hub
  project  = var.ncc_project_id
  role     = "roles/networkconnectivity.spokeAdmin"
  member   = "serviceAccount:${each.value.service_account}"
}


# GCS bucket for shared secrets
resource "google_storage_bucket" "shared_secrets" {
  provider                    = google.ncc_hub
  name                        = var.gcs_bucket_name
  project                     = var.ncc_project_id
  location                    = var.ncc_region
  force_destroy               = true
  uniform_bucket_level_access = true
  versioning {
    enabled = true
  }
}

# Spoke service account access to shared secrets bucket
resource "google_storage_bucket_iam_member" "spoke_secret_reader" {
  for_each = { for spoke in var.spoke_configs : spoke.name => spoke }
  provider = google.ncc_hub
  bucket   = google_storage_bucket.shared_secrets.name
  role     = "roles/storage.objectViewer"
  member   = "serviceAccount:${each.value.service_account}"
}

# Shared secret for each spoke
resource "random_id" "shared_secret" {
  for_each    = { for spoke in var.spoke_configs : spoke.name => spoke }
  byte_length = 16
}

resource "google_storage_bucket_object" "shared_secret" {
  for_each = { for spoke in var.spoke_configs : spoke.name => spoke }
  provider = google.ncc_hub
  name     = "shared-secrets/${each.key}-shared-secret.txt"
  bucket   = google_storage_bucket.shared_secrets.name
  content  = random_id.shared_secret[each.key].hex
}

# NCC hub test VM
resource "google_compute_instance" "ncc_test_vm" {
  count        = var.deploy_test_vm ? 1 : 0
  provider     = google.ncc_hub
  name         = "${var.prefix}-ncc-test-vm"
  project      = var.ncc_project_id
  zone         = "${var.ncc_region}-a"
  machine_type = var.test_vm_machine_type
  boot_disk {
    initialize_params {
      image = var.test_vm_image
    }
  }
  network_interface {
    network    = google_compute_network.ncc_vpc.self_link
    subnetwork = google_compute_subnetwork.ncc_subnet.self_link
  }
  tags = ["${var.prefix}-ncc-vm"]
}

# Firewall rule to allow SSH via IAP
resource "google_compute_firewall" "ncc_allow_iap_ssh" {
  provider  = google.ncc_hub
  name      = "${var.prefix}-ncc-allow-iap-ssh"
  project   = var.ncc_project_id
  network   = google_compute_network.ncc_vpc.self_link
  priority  = 1000
  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["${var.prefix}-ncc-vm"]
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

#############################
######### Phase 2 ##########
#############################

# Retrieving spoke outputs from Terraform state
data "terraform_remote_state" "spoke" {
  for_each = var.deploy_phase2 ? { for spoke in var.spoke_configs : spoke.name => spoke } : {}
  backend  = "gcs"
  config = {
    bucket      = each.value.spoke_statefile_bucket_name
    prefix      = each.value.spoke_state_prefix
    credentials = var.ncc_credentials_path
  }
}

# Retrieving shared secrets from GCS
data "google_storage_bucket_object_content" "shared_secret" {
  for_each = var.deploy_phase2 ? { for spoke in var.spoke_configs : spoke.name => spoke } : {}
  name     = "shared-secrets/${each.key}-shared-secret.txt"
  bucket   = var.gcs_bucket_name
}

# Creating VPN tunnels for each spoke (tunnel 0)
resource "google_compute_vpn_tunnel" "ncc_to_spoke_0" {
  for_each              = var.deploy_phase2 ? { for spoke in var.spoke_configs : spoke.name => spoke } : {}
  name                  = "${var.prefix}-ncc-to-${each.key}-0"
  project               = var.ncc_project_id
  region                = var.ncc_region
  vpn_gateway           = google_compute_ha_vpn_gateway.ncc_vpn_gateway.id
  vpn_gateway_interface = 0
  peer_gcp_gateway      = data.terraform_remote_state.spoke[each.key].outputs.spoke_vpn_gateway_id
  shared_secret         = data.google_storage_bucket_object_content.shared_secret[each.key].content
  ike_version           = 2
  router                = google_compute_router.ncc_cloud_router.name
}

# Creating VPN tunnels for each spoke (tunnel 1)
resource "google_compute_vpn_tunnel" "ncc_to_spoke_1" {
  for_each              = var.deploy_phase2 ? { for spoke in var.spoke_configs : spoke.name => spoke } : {}
  name                  = "${var.prefix}-ncc-to-${each.key}-1"
  project               = var.ncc_project_id
  region                = var.ncc_region
  vpn_gateway           = google_compute_ha_vpn_gateway.ncc_vpn_gateway.id
  vpn_gateway_interface = 1
  peer_gcp_gateway      = data.terraform_remote_state.spoke[each.key].outputs.spoke_vpn_gateway_id
  shared_secret         = data.google_storage_bucket_object_content.shared_secret[each.key].content
  ike_version           = 2
  router                = google_compute_router.ncc_cloud_router.name
}

# Creating NCC Cloud Router interfaces for each spoke (tunnel 0)
resource "google_compute_router_interface" "ncc_to_spoke_0" {
  for_each   = var.deploy_phase2 ? { for spoke in var.spoke_configs : spoke.name => spoke } : {}
  name       = "${var.prefix}-ncc-to-${each.key}-0"
  project    = var.ncc_project_id
  router     = google_compute_router.ncc_cloud_router.name
  region     = var.ncc_region # Use spoke’s region (asia-northeast1)
  ip_range   = each.value.ncc_to_spoke_ip_range_0
  vpn_tunnel = google_compute_vpn_tunnel.ncc_to_spoke_0[each.key].name
  depends_on = [google_compute_vpn_tunnel.ncc_to_spoke_0]
}

# Creating NCC Cloud Router peers for each spoke (tunnel 0)
resource "google_compute_router_peer" "ncc_to_spoke_0" {
  for_each        = var.deploy_phase2 ? { for spoke in var.spoke_configs : spoke.name => spoke } : {}
  name            = "${var.prefix}-ncc-to-${each.key}-0"
  project         = var.ncc_project_id
  router          = google_compute_router.ncc_cloud_router.name
  region          = var.ncc_region # Use spoke’s region (asia-northeast1)
  peer_ip_address = each.value.spoke_to_ncc_peer_ip_0
  peer_asn        = data.terraform_remote_state.spoke[each.key].outputs.spoke_asn
  interface       = google_compute_router_interface.ncc_to_spoke_0[each.key].name
  depends_on      = [google_compute_router_interface.ncc_to_spoke_0]
}

# Creating NCC Cloud Router interfaces for each spoke (tunnel 1)
resource "google_compute_router_interface" "ncc_to_spoke_1" {
  for_each   = var.deploy_phase2 ? { for spoke in var.spoke_configs : spoke.name => spoke } : {}
  name       = "${var.prefix}-ncc-to-${each.key}-1"
  project    = var.ncc_project_id
  router     = google_compute_router.ncc_cloud_router.name
  region     = var.ncc_region # Use spoke’s region (asia-northeast1)
  ip_range   = each.value.ncc_to_spoke_ip_range_1
  vpn_tunnel = google_compute_vpn_tunnel.ncc_to_spoke_1[each.key].name
  depends_on = [google_compute_vpn_tunnel.ncc_to_spoke_1]
}

# Creating NCC Cloud Router peers for each spoke (tunnel 1)
resource "google_compute_router_peer" "ncc_to_spoke_1" {
  for_each        = var.deploy_phase2 ? { for spoke in var.spoke_configs : spoke.name => spoke } : {}
  name            = "${var.prefix}-ncc-to-${each.key}-1"
  project         = var.ncc_project_id
  router          = google_compute_router.ncc_cloud_router.name
  region          = var.ncc_region # Use spoke’s region (asia-northeast1)
  peer_ip_address = each.value.spoke_to_ncc_peer_ip_1
  peer_asn        = data.terraform_remote_state.spoke[each.key].outputs.spoke_asn
  interface       = google_compute_router_interface.ncc_to_spoke_1[each.key].name
  depends_on      = [google_compute_router_interface.ncc_to_spoke_1]
}

# Creating NCC spoke resources for VPN tunnels
resource "google_network_connectivity_spoke" "vpn_spoke" {
  for_each = var.deploy_phase2 ? { for spoke in var.spoke_configs : spoke.name => spoke } : {}
  name     = "${var.prefix}-vpn-${each.key}"
  project  = var.ncc_project_id
  location = var.ncc_region # Use spoke’s region (asia-northeast1)
  hub      = google_network_connectivity_hub.ncc_hub.id
  linked_vpn_tunnels {
    uris = [
      google_compute_vpn_tunnel.ncc_to_spoke_0[each.key].self_link,
      google_compute_vpn_tunnel.ncc_to_spoke_1[each.key].self_link
    ]
    site_to_site_data_transfer = true
  }
  depends_on = [
    google_compute_vpn_tunnel.ncc_to_spoke_0,
    google_compute_vpn_tunnel.ncc_to_spoke_1
  ]
  lifecycle {
    # Ignore changes to 'name' and 'linked_vpn_tunnels[0].uris'.
    # The 'name' attribute is often updated automatically by GCP, causing unnecessary resource replacements, 
    # but the actual functionality doesn't change. By ignoring this, we prevent the resource from being 
    # destroyed and recreated unnecessarily.
    #
    # The 'linked_vpn_tunnels[0].uris' can also change in format (e.g., full URL vs. a shortened version), 
    # but it doesn't impact the actual functionality of the VPN connections. This is why we ignore it too,
    # to avoid triggering unnecessary changes that don't impact the operation of the infrastructure.
    ignore_changes = [name, linked_vpn_tunnels[0].uris]
  }
}

# Creating firewall rule for VPN and BGP traffic
resource "google_compute_firewall" "ncc_allow_vpn_bgp" {
  count     = var.deploy_phase2 ? 1 : 0
  name      = "${var.prefix}-ncc-allow-vpn-bgp"
  project   = var.ncc_project_id
  network   = google_compute_network.ncc_vpc.id
  direction = "INGRESS"
  allow {
    protocol = "tcp"
    ports    = ["179"]
  }
  allow {
    protocol = "udp"
    ports    = ["500", "4500"]
  }
  allow {
    protocol = "esp"
  }
  source_ranges = [for spoke in var.spoke_configs : data.terraform_remote_state.spoke[spoke.name].outputs.spoke_subnet_cidr]
  priority      = 1000
  description   = "Allows VPN and BGP traffic from spoke to NCC hub"
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

#############################
######### Phase 3 ##########
#############################

# Creating firewall rule for spoke-to-spoke traffic
resource "google_compute_firewall" "ncc_allow_spoke_to_spoke" {
  count       = var.deploy_phase3 ? 1 : 0
  name        = "${var.prefix}-ncc-allow-spoke-to-spoke"
  project     = var.ncc_project_id
  network     = google_compute_network.ncc_vpc.id
  direction   = "INGRESS"
  description = "Allows spoke-to-spoke traffic"
  priority    = 1000
  allow {
    protocol = "all"
  }
  # Constructs source_ranges and destination_ranges for NCC ingress firewall rule.
  # Includes:
  # - The NCC subnet CIDR (local to the NCC VPC)
  # - All spoke subnet CIDRs retrieved from remote state (via spoke_configs)
  # This ensures:
  # - NCC VMs can receive traffic from any spoke subnet
  # - Traffic can be routed through NCC to other spokes (hub-style)
  # - The rule remains dynamic and scalable across multiple spokes
  source_ranges = concat(
    [google_compute_subnetwork.ncc_subnet.ip_cidr_range],
    [for spoke in var.spoke_configs : data.terraform_remote_state.spoke[spoke.name].outputs.spoke_subnet_cidr]
  )
  destination_ranges = concat(
    [google_compute_subnetwork.ncc_subnet.ip_cidr_range],
    [for spoke in var.spoke_configs : data.terraform_remote_state.spoke[spoke.name].outputs.spoke_subnet_cidr]
  )
  target_tags = ["${var.prefix}-ncc-vm"]
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}