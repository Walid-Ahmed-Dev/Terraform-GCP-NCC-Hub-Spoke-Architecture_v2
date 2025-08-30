# Prefix for resource names to ensure uniqueness across spoke resources
variable "prefix" {
  description = "Prefix for resource names to ensure uniqueness in the spoke project"
  type        = string
  default     = "walid"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}[a-z0-9]$", var.prefix))
    error_message = "Prefix must start with a letter, contain only lowercase letters, numbers, or hyphens, and be 3-32 characters long."
  }
}

# GCP project ID for the spoke
variable "spoke_project_id" {
  description = "GCP project ID for the spoke project"
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.spoke_project_id))
    error_message = "Project ID must be 6-30 characters, start with a letter, and contain only lowercase letters, numbers, or hyphens."
  }
}

# GCP region for the spoke
variable "spoke_region" {
  description = "GCP region for spoke resources (e.g., us-central1)"
  type        = string
  default     = "us-central1"
}

# CIDR range for the spoke subnet
variable "spoke_subnet_cidr" {
  description = "CIDR range for the spoke subnet, used in Phase 1 for VPC creation"
  type        = string
  validation {
    condition     = can(cidrhost(var.spoke_subnet_cidr, 0))
    error_message = "Must be a valid CIDR range."
  }
}

# BGP ASN for the spoke
variable "spoke_asn" {
  description = "BGP ASN for the spoke Cloud Router, used for BGP peering with the hub"
  type        = number
  default     = 64513
  validation {
    condition     = var.spoke_asn >= 64512 && var.spoke_asn <= 65535
    error_message = "ASN must be in the private range (64512-65535)."
  }
}

# Path to the spoke GCP credentials JSON file
variable "spoke_credentials_path" {
  description = "Path to the GCP credentials JSON file for the spoke project"
  type        = string
  sensitive   = true
}

# GCS bucket for spoke Phase 1 state
variable "spoke_statefile_bucket_name" {
  description = "GCS bucket where the Phase 1 state for this spoke is stored"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-_.]{1,220}[a-z0-9]$", var.spoke_statefile_bucket_name))
    error_message = "GCS bucket name must be 3-222 characters, start and end with a letter or number, and contain only lowercase letters, numbers, hyphens, underscores, or periods."
  }
}

# Name identifier for the spoke
variable "spoke_name" {
  description = "Name identifier for the spoke (used in state lookups and resource naming)"
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}[a-z0-9]$", var.spoke_name))
    error_message = "Spoke name must start with a letter, contain only lowercase letters, numbers, or hyphens, and be 3-32 characters long."
  }
}

# Service account email for the NCC hub
variable "hub_service_account" {
  description = "Service account email for the NCC hub project, used for IAM and resource access"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-._]+@[a-z0-9-._]+\\.iam\\.gserviceaccount\\.com$", var.hub_service_account))
    error_message = "Must be a valid GCP service account email."
  }
}

# Whether to deploy a test VM in the spoke
variable "deploy_test_vm" {
  description = "Whether to deploy a test VM in the spoke in Phase 1"
  type        = bool
  default     = true
}

# Machine type for the spoke test VM
variable "test_vm_machine_type" {
  description = "Machine type for the spoke test VM in Phase 1"
  type        = string
  default     = "e2-micro"
}

# Disk image for the spoke test VM
variable "test_vm_image" {
  description = "Disk image for the spoke test VM in Phase 1"
  type        = string
  default     = "debian-cloud/debian-11"
}

#############################
######### Phase 2 ##########
#############################

# GCS bucket containing shared secrets between hub and spoke
variable "gcs_bucket_name" {
  description = "Name of the GCS bucket containing shared secrets for hub and spoke connectivity"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-_.]{1,220}[a-z0-9]$", var.gcs_bucket_name))
    error_message = "GCS bucket name must be 3-222 characters, start and end with a letter or number, and contain only lowercase letters, numbers, hyphens, underscores, or periods."
  }
}

# GCS bucket where the hub's Phase 1 state is stored
variable "hub_state_bucket_name" {
  description = "GCS bucket where the hub's Phase 1 state is stored"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-_.]{1,220}[a-z0-9]$", var.hub_state_bucket_name))
    error_message = "GCS bucket name must be 3-222 characters, start and end with a letter or number, and contain only lowercase letters, numbers, hyphens, underscores, or periods."
  }
}

# Hub prefix for state lookup
variable "hub_prefix" {
  description = "Prefix for the hub (used to locate its state in GCS)"
  type        = string
}

# IP range for the spoke-to-hub VPN tunnel 0 interface
variable "spoke_to_ncc_ip_range_0" {
  description = "IP range for the spoke-to-hub VPN tunnel 0 interface"
  type        = string
  validation {
    condition     = can(cidrhost(var.spoke_to_ncc_ip_range_0, 0))
    error_message = "Must be a valid CIDR range."
  }
}

# IP range for the spoke-to-hub VPN tunnel 1 interface
variable "spoke_to_ncc_ip_range_1" {
  description = "IP range for the spoke-to-hub VPN tunnel 1 interface"
  type        = string
  validation {
    condition     = can(cidrhost(var.spoke_to_ncc_ip_range_1, 0))
    error_message = "Must be a valid CIDR range."
  }
}

# Hub-side BGP peer IP address for tunnel 0
variable "ncc_to_spoke_peer_ip_0" {
  description = "Hub-side BGP peer IP address for tunnel 0"
  type        = string
  validation {
    condition     = can(regex("^[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}$", var.ncc_to_spoke_peer_ip_0))
    error_message = "Must be a valid IPv4 address."
  }
}

# Hub-side BGP peer IP address for tunnel 1
variable "ncc_to_spoke_peer_ip_1" {
  description = "Hub-side BGP peer IP address for tunnel 1"
  type        = string
  validation {
    condition     = can(regex("^[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}$", var.ncc_to_spoke_peer_ip_1))
    error_message = "Must be a valid IPv4 address."
  }
}

variable "deploy_phase2" {
  description = "Whether to deploy phase 2 resources (VPN tunnels, router interfaces, etc.)"
  type        = bool
  default     = false
}