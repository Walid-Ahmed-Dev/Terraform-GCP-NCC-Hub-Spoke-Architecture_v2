terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}
# Create public subnet for Windows VM in a different region
resource "google_compute_subnetwork" "task3_public_subnet" {
  count                    = var.deploy_task_3 ? 1 : 0
  provider                 = google
  name                     = "${var.prefix}-spoke-${var.spoke_name}-task3-public-subnet"
  project                  = var.spoke_project_id
  region                   = var.windows_vm_region
  network                  = var.spoke_vpc_id
  ip_cidr_range            = var.task3_private_cidr
  private_ip_google_access = true
}



# Router for private subnet (Linux VMs need NAT for internet access)
resource "google_compute_router" "task3_private_router" {
  count    = var.deploy_task_3 ? 1 : 0
  provider = google
  name     = "${var.prefix}-spoke-${var.spoke_name}-task3-private-router"
  project  = var.spoke_project_id
  region   = var.spoke_region
  network  = var.spoke_vpc_id
}

# NAT for Linux VMs private subnet 
resource "google_compute_router_nat" "task3_private_nat" {
  count                              = var.deploy_task_3 ? 1 : 0
  provider                           = google
  name                               = "${var.prefix}-spoke-${var.spoke_name}-task3-linux-nat"
  router                             = google_compute_router.task3_private_router[0].name
  project                            = var.spoke_project_id
  region                             = var.spoke_region
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  nat_ip_allocate_option             = "MANUAL_ONLY"
  nat_ips                            = [google_compute_address.task3_private_nat_ip[0].self_link]

  subnetwork {
    name                    = var.spoke_subnet_id # Existing private subnet
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}

# NAT IP for private subnet
resource "google_compute_address" "task3_private_nat_ip" {
  count        = var.deploy_task_3 ? 1 : 0
  provider     = google
  name         = "${var.prefix}-spoke-${var.spoke_name}-task3-private-nat-ip"
  project      = var.spoke_project_id
  region       = var.spoke_region
  address_type = "EXTERNAL"
}

# Firewall rule for RDP access to Windows VM
resource "google_compute_firewall" "task3_rdp_access" {
  count    = var.deploy_task_3 ? 1 : 0
  provider = google
  name     = "${var.prefix}-spoke-${var.spoke_name}-task3-allow-rdp"
  project  = var.spoke_project_id
  network  = var.spoke_vpc_id

  allow {
    protocol = "tcp"
    ports    = ["3389"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["${var.prefix}-spoke-${var.spoke_name}-task3-windows-vm"]
}

# Firewall rule for Windows to Linux communication
resource "google_compute_firewall" "task3_windows_to_linux" {
  count    = var.deploy_task_3 ? 1 : 0
  provider = google
  name     = "${var.prefix}-spoke-${var.spoke_name}-task3-windows-to-linux"
  project  = var.spoke_project_id
  network  = var.spoke_vpc_id

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_tags = ["${var.prefix}-spoke-${var.spoke_name}-task3-windows-vm"]
  target_tags = ["${var.prefix}-spoke-${var.spoke_name}-task3-${var.group_member}-linux-vm"]
}

# Windows VM in public subnet
# Windows VM - NO NAT NEEDED (uses public IP directly)
resource "google_compute_instance" "task3_windows_vm" {
  count        = var.deploy_task_3 ? 1 : 0
  provider     = google
  name         = "${var.prefix}-spoke-${var.spoke_name}-task3-windows-vm"
  project      = var.spoke_project_id
  zone         = "${var.windows_vm_region}-a"
  machine_type = var.windows_vm_machine_type
  tags         = ["${var.prefix}-spoke-${var.spoke_name}-task3-windows-vm"]

  boot_disk {
    initialize_params {
      image = "windows-cloud/windows-2022"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.task3_public_subnet[0].id
    access_config {
      # Ephemeral public IP - NO NAT NEEDED
    }
  }
}

# Internal load balancer IP address
resource "google_compute_address" "task3_internal_lb_ip" {
  count        = var.deploy_task_3 ? 1 : 0
  provider     = google
  name         = "${var.prefix}-spoke-${var.spoke_name}-task3-internal-lb-ip"
  project      = var.spoke_project_id
  region       = var.spoke_region
  subnetwork   = var.spoke_subnet_id
  address_type = "INTERNAL"
}

# Internal load balancer
resource "google_compute_forwarding_rule" "task3_internal_lb" {
  count                 = var.deploy_task_3 ? 1 : 0
  provider              = google
  name                  = "${var.prefix}-spoke-${var.spoke_name}-task3-internal-lb"
  project               = var.spoke_project_id
  region                = var.spoke_region
  load_balancing_scheme = "INTERNAL"
  backend_service       = google_compute_region_backend_service.task3_linux_backend[0].self_link
  ip_address            = google_compute_address.task3_internal_lb_ip[0].address
  ip_protocol           = "TCP"
  ports                 = ["80"]
  subnetwork            = var.spoke_subnet_id
}

# Backend service for internal load balancer
resource "google_compute_region_backend_service" "task3_linux_backend" {
  count                 = var.deploy_task_3 ? 1 : 0
  provider              = google
  name                  = "${var.prefix}-spoke-${var.spoke_name}-task3-linux-backend"
  project               = var.spoke_project_id
  region                = var.spoke_region
  protocol              = "TCP"
  load_balancing_scheme = "INTERNAL"
  health_checks         = [google_compute_region_health_check.task3_linux_hc[0].id]

  backend {
    group          = google_compute_region_instance_group_manager.task3_linux_mig[0].instance_group
    balancing_mode = "CONNECTION"
  }
}

# Health check for Linux VMs
resource "google_compute_region_health_check" "task3_linux_hc" {
  count              = var.deploy_task_3 ? 1 : 0
  provider           = google
  name               = "${var.prefix}-spoke-${var.spoke_name}-task3-linux-hc"
  project            = var.spoke_project_id
  check_interval_sec = 5
  timeout_sec        = 5

  log_config {
    enable = true
  }
  tcp_health_check {
    port = 80
  }
}

# Linux VM instance template
resource "google_compute_instance_template" "task3_linux_template" {
  count        = var.deploy_task_3 ? 1 : 0
  provider     = google
  name_prefix  = "${var.prefix}-spoke-${var.spoke_name}-task3-linux-template-"
  project      = var.spoke_project_id
  machine_type = var.linux_vm_machine_type
  tags         = ["${var.prefix}-spoke-${var.spoke_name}-task3-${var.group_member}-linux-vm"]

  disk {
    source_image = "debian-cloud/debian-12"
    boot         = true
  }

  network_interface {
    subnetwork = var.spoke_subnet_id
  }

  metadata_startup_script = file("${path.module}/scripts/webserver.sh")

  lifecycle {
    create_before_destroy = true
  }
}

# Managed instance group for Linux VMs
resource "google_compute_region_instance_group_manager" "task3_linux_mig" {
  count              = var.deploy_task_3 ? 1 : 0
  provider           = google
  name               = "${var.prefix}-spoke-${var.spoke_name}-task3-linux-mig"
  project            = var.spoke_project_id
  region             = var.spoke_region
  base_instance_name = "${var.prefix}-spoke-${var.spoke_name}-task3-linux-vm"
  target_size        = 2

  version {
    instance_template = google_compute_instance_template.task3_linux_template[0].id
  }

  distribution_policy_zones = [
    "${var.spoke_region}-a",
    "${var.spoke_region}-b"
  ]

  named_port {
    name = "http"
    port = 80
  }
}

