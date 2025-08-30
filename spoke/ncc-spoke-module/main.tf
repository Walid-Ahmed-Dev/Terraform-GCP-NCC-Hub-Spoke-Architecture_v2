terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

# Provider configuration
provider "google" {
  project     = var.spoke_project_id
  region      = var.spoke_region
  credentials = file(var.spoke_credentials_path)
  alias       = "spoke"
}


# Creating spoke VPC 
resource "google_compute_network" "spoke_vpc" {
  provider                = google.spoke
  name                    = "${var.prefix}-spoke-${var.spoke_name}-vpc"
  project                 = var.spoke_project_id
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

# Creating spoke subnet 
resource "google_compute_subnetwork" "spoke_subnet" {
  provider                 = google.spoke
  name                     = "${var.prefix}-spoke-${var.spoke_name}-subnet"
  project                  = var.spoke_project_id
  region                   = var.spoke_region
  network                  = google_compute_network.spoke_vpc.self_link
  ip_cidr_range            = var.spoke_subnet_cidr
  private_ip_google_access = false
}

# Deploying spoke HA VPN gateway 
resource "google_compute_ha_vpn_gateway" "spoke_vpn_gateway" {
  provider = google.spoke
  name     = "${var.prefix}-spoke-${var.spoke_name}-vpn-gateway"
  project  = var.spoke_project_id
  region   = var.spoke_region
  network  = google_compute_network.spoke_vpc.self_link
}

# Deploying spoke Cloud Router 
resource "google_compute_router" "spoke_cloud_router" {
  provider = google.spoke
  name     = "${var.prefix}-spoke-${var.spoke_name}-cloud-router"
  project  = var.spoke_project_id
  region   = var.spoke_region
  network  = google_compute_network.spoke_vpc.self_link
  bgp {
    asn = var.spoke_asn
  }
}

# Granting hub service account compute.networkUser role in spoke project
resource "google_project_iam_member" "hub_network_user" {
  provider = google.spoke
  project  = var.spoke_project_id
  role     = "roles/compute.networkUser"
  member   = "serviceAccount:${var.hub_service_account}"
}

# Allow hub SA to read statefile and use lock files
resource "google_storage_bucket_iam_member" "hub_state_admin" {
  provider = google.spoke
  bucket   = var.spoke_statefile_bucket_name
  role     = "roles/storage.objectAdmin"
  member   = "serviceAccount:${var.hub_service_account}"
}

# Deploying spoke test VM 
resource "google_compute_instance" "spoke_test_vm" {
  count        = var.deploy_test_vm ? 1 : 0
  provider     = google.spoke
  name         = "${var.prefix}-spoke-${var.spoke_name}-test-vm"
  project      = var.spoke_project_id
  zone         = "${var.spoke_region}-a"
  machine_type = var.test_vm_machine_type
  tags         = ["${var.prefix}-spoke-${var.spoke_name}-vm"]
  boot_disk {
    initialize_params {
      image = var.test_vm_image
    }
  }
  network_interface {
    network    = google_compute_network.spoke_vpc.self_link
    subnetwork = google_compute_subnetwork.spoke_subnet.self_link
    access_config {}
  }
  depends_on = [google_compute_subnetwork.spoke_subnet]
}

# Creating firewall rule for test VM SSH access 
resource "google_compute_firewall" "spoke_allow_iap_ssh" {
  provider = google.spoke
  count    = var.deploy_test_vm ? 1 : 0
  name     = "${var.prefix}-spoke-${var.spoke_name}-allow-iap-ssh"
  project  = var.spoke_project_id
  network  = google_compute_network.spoke_vpc.self_link
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["${var.prefix}-spoke-${var.spoke_name}-vm"]
  priority      = 1000
  description   = "Allows SSH access via IAP for spoke ${var.spoke_name} test VM"
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

#############################
######### Phase 2 ##########
#############################

# Retrieving hub outputs from Terraform state
data "terraform_remote_state" "hub" {
  count   = var.deploy_phase2 ? 1 : 0
  backend = "gcs"
  config = {
    bucket      = var.hub_state_bucket_name
    prefix      = var.hub_prefix
    credentials = var.spoke_credentials_path
  }
}

# Retrieving shared secret from GCS 
data "google_storage_bucket_object_content" "shared_secret" {
  count  = var.deploy_phase2 ? 1 : 0
  name   = "shared-secrets/${var.spoke_name}-shared-secret.txt"
  bucket = var.gcs_bucket_name
}

# Creating VPN tunnels for spoke to NCC hub (tunnel 0)
resource "google_compute_vpn_tunnel" "spoke_to_ncc_0" {
  count                 = var.deploy_phase2 ? 1 : 0
  name                  = "${var.prefix}-spoke-${var.spoke_name}-to-ncc-0"
  project               = var.spoke_project_id
  region                = var.spoke_region
  vpn_gateway           = google_compute_ha_vpn_gateway.spoke_vpn_gateway.id # deployed in phase 1
  vpn_gateway_interface = 0
  peer_gcp_gateway      = data.terraform_remote_state.hub[0].outputs.ncc_vpn_gateway_id
  shared_secret         = data.google_storage_bucket_object_content.shared_secret[0].content
  ike_version           = 2
  router                = google_compute_router.spoke_cloud_router.name # deployed in phase 1
}

# Creating VPN tunnel for spoke to NCC hub (tunnel 1)
resource "google_compute_vpn_tunnel" "spoke_to_ncc_1" {
  count                 = var.deploy_phase2 ? 1 : 0
  name                  = "${var.prefix}-spoke-${var.spoke_name}-to-ncc-1"
  project               = var.spoke_project_id
  region                = var.spoke_region
  vpn_gateway           = google_compute_ha_vpn_gateway.spoke_vpn_gateway.id # deployed in phase 1
  vpn_gateway_interface = 1
  peer_gcp_gateway      = data.terraform_remote_state.hub[0].outputs.ncc_vpn_gateway_id
  shared_secret         = data.google_storage_bucket_object_content.shared_secret[0].content
  ike_version           = 2
  router                = google_compute_router.spoke_cloud_router.name # deployed in phase 1
}

# Creating Cloud Router interface (tunnel 0)
resource "google_compute_router_interface" "spoke_to_ncc_0" {
  count      = var.deploy_phase2 ? 1 : 0
  name       = "${var.prefix}-spoke-${var.spoke_name}-to-ncc-0"
  project    = var.spoke_project_id
  router     = google_compute_router.spoke_cloud_router.name # deployed in phase 1
  region     = var.spoke_region
  ip_range   = var.spoke_to_ncc_ip_range_0
  vpn_tunnel = google_compute_vpn_tunnel.spoke_to_ncc_0[0].name
  depends_on = [google_compute_vpn_tunnel.spoke_to_ncc_0]
}

# Creating Cloud Router peer (tunnel 0) 
resource "google_compute_router_peer" "spoke_to_ncc_0" {
  count           = var.deploy_phase2 ? 1 : 0
  name            = "${var.prefix}-spoke-${var.spoke_name}-to-ncc-0"
  project         = var.spoke_project_id
  router          = google_compute_router.spoke_cloud_router.name # deployed in phase 1
  region          = var.spoke_region
  peer_ip_address = var.ncc_to_spoke_peer_ip_0
  peer_asn        = data.terraform_remote_state.hub[0].outputs.ncc_asn
  interface       = google_compute_router_interface.spoke_to_ncc_0[0].name
  depends_on      = [google_compute_router_interface.spoke_to_ncc_0]
}

# Creating Cloud Router interface (tunnel 1) 
resource "google_compute_router_interface" "spoke_to_ncc_1" {
  count      = var.deploy_phase2 ? 1 : 0
  name       = "${var.prefix}-spoke-${var.spoke_name}-to-ncc-1"
  project    = var.spoke_project_id
  router     = google_compute_router.spoke_cloud_router.name # deployed in phase 1 
  region     = var.spoke_region
  ip_range   = var.spoke_to_ncc_ip_range_1
  vpn_tunnel = google_compute_vpn_tunnel.spoke_to_ncc_1[0].name
  depends_on = [google_compute_vpn_tunnel.spoke_to_ncc_1]
}

# Creating Cloud Router peer (tunnel 1)
resource "google_compute_router_peer" "spoke_to_ncc_1" {
  count           = var.deploy_phase2 ? 1 : 0
  name            = "${var.prefix}-spoke-${var.spoke_name}-to-ncc-1"
  project         = var.spoke_project_id
  router          = google_compute_router.spoke_cloud_router.name # deployed in phase 1 
  region          = var.spoke_region
  peer_ip_address = var.ncc_to_spoke_peer_ip_1
  peer_asn        = data.terraform_remote_state.hub[0].outputs.ncc_asn
  interface       = google_compute_router_interface.spoke_to_ncc_1[0].name
  depends_on      = [google_compute_router_interface.spoke_to_ncc_1]
}

# Creating firewall rule for VPN and BGP traffic 
resource "google_compute_firewall" "spoke_allow_vpn_bgp" {
  count   = var.deploy_phase2 ? 1 : 0
  name    = "${var.prefix}-spoke-${var.spoke_name}-allow-vpn-bgp"
  project = var.spoke_project_id
  network = google_compute_network.spoke_vpc.id
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
  source_ranges = [data.terraform_remote_state.hub[0].outputs.ncc_subnet_cidr]
  priority      = 1000
  description   = "Allows VPN and BGP traffic from NCC hub to spoke ${var.spoke_name}"
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# Creating firewall rule for spoke-to-spoke traffic 
resource "google_compute_firewall" "spoke_allow_spoke_to_spoke" {
  count       = var.deploy_phase2 ? 1 : 0
  name        = "${var.prefix}-spoke-${var.spoke_name}-allow-spoke-to-spoke"
  project     = var.spoke_project_id
  network     = google_compute_network.spoke_vpc.id
  description = "Allows spoke-to-spoke traffic for spoke ${var.spoke_name}"
  priority    = 1000
  allow {
    protocol = "all"
  }
  source_ranges = [
    data.terraform_remote_state.hub[0].outputs.ncc_subnet_cidr,
    google_compute_subnetwork.spoke_subnet.ip_cidr_range
  ]
  destination_ranges = [
    data.terraform_remote_state.hub[0].outputs.ncc_subnet_cidr,
    google_compute_subnetwork.spoke_subnet.ip_cidr_range
  ]
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}