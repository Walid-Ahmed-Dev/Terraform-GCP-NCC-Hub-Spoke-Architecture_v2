# Prefix for resource names to ensure uniqueness across hub resources
variable "prefix" {
  description = "Prefix for resource names to ensure uniqueness in the NCC hub project"
  type        = string
  default     = "walid"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}[a-z0-9]$", var.prefix))
    error_message = "Prefix must start with a letter, contain only lowercase letters, numbers, or hyphens, and be 3-32 characters long."
  }
}

# GCP project ID for the NCC hub
variable "ncc_project_id" {
  description = "GCP project ID for the NCC hub project"
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.ncc_project_id))
    error_message = "Project ID must be 6-30 characters, start with a letter, and contain only lowercase letters, numbers, or hyphens."
  }
}

# GCP region for the NCC hub
variable "ncc_region" {
  description = "GCP region for NCC hub resources (e.g., us-central1)"
  type        = string
  default     = "us-central1"
}

# CIDR range for the NCC hub subnet
variable "ncc_subnet_cidr" {
  description = "CIDR range for the NCC hub subnet, used in Phase 1 for VPC creation"
  type        = string
  default     = "10.190.0.0/24"
  validation {
    condition     = can(cidrhost(var.ncc_subnet_cidr, 0))
    error_message = "Must be a valid CIDR range."
  }
}

# BGP ASN for the NCC hub
variable "ncc_asn" {
  description = "BGP ASN for the NCC hub Cloud Router, used in Phase 1 for router creation and Phase 2 for BGP peering"
  type        = number
  default     = 64512
  validation {
    condition     = var.ncc_asn >= 64512 && var.ncc_asn <= 65535
    error_message = "ASN must be in the private range (64512-65535)."
  }
}

# Path to the NCC hub GCP credentials JSON file
variable "ncc_credentials_path" {
  description = "Path to the GCP credentials JSON file for the NCC hub project"
  type        = string
  sensitive   = true
}

# Service account email for the NCC hub project
variable "ncc_hub_service_account" {
  description = "Service account email for the NCC hub project, used for resource management and GCS access"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-._]+@[a-z0-9-._]+\\.iam\\.gserviceaccount\\.com$", var.ncc_hub_service_account))
    error_message = "Must be a valid GCP service account email."
  }
}

variable "ncc-hub_statefile_bucket_name" {
  type = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-_.]{1,220}[a-z0-9]$", var.ncc-hub_statefile_bucket_name))
    error_message = "GCS bucket name must be 3-222 characters, start and end with a letter or number, and contain only lowercase letters, numbers, hyphens, underscores, or periods."
  }
}

# Name of the GCS bucket to store shared secrets
variable "gcs_bucket_name" {
  description = "Name of the GCS bucket to store shared secrets for hub and spoke connectivity"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-_.]{1,220}[a-z0-9]$", var.gcs_bucket_name))
    error_message = "GCS bucket name must be 3-222 characters, start and end with a letter or number, and contain only lowercase letters, numbers, hyphens, underscores, or periods."
  }
}

# List of spoke configurations for IAM and VPN connectivity
variable "spoke_configs" {
  description = "List of spoke configurations for IAM in Phase 1 (service_account) and VPN connectivity in Phase 2 (IP ranges and peer IPs)"
  type = list(object({
    name                        = string
    spoke_statefile_bucket_name = string
    spoke_state_prefix          = string
    service_account             = string
    ncc_to_spoke_ip_range_0     = string
    spoke_to_ncc_peer_ip_0      = string
    ncc_to_spoke_ip_range_1     = string
    spoke_to_ncc_peer_ip_1      = string
  }))
  default = []
  validation {
    condition = alltrue([
      for spoke in var.spoke_configs : can(regex("^[a-z][a-z0-9-]{1,30}[a-z0-9]$", spoke.name))
    ])
    error_message = "Each spoke name must start with a letter, contain only lowercase letters, numbers, or hyphens, and be 3-32 characters long."
  }
  validation {
    condition = alltrue([
      for spoke in var.spoke_configs : can(regex("^[a-z0-9][a-z0-9-_.]{1,220}[a-z0-9]$", spoke.spoke_statefile_bucket_name))
    ])
    error_message = "Each spoke state bucket name must be 3-222 characters, start and end with a letter or number, and contain only lowercase letters, numbers, hyphens, underscores, or periods."
  }
  validation {
    condition = alltrue([
      for spoke in var.spoke_configs : can(regex("^[a-z0-9-._]+@[a-z0-9-._]+\\.iam\\.gserviceaccount\\.com$", spoke.service_account))
    ])
    error_message = "Each spoke service account must be a valid GCP service account email."
  }
  validation {
    condition = alltrue([
      for spoke in var.spoke_configs : can(cidrhost(spoke.ncc_to_spoke_ip_range_0, 0))
    ])
    error_message = "Each ncc_to_spoke_ip_range_0 must be a valid CIDR range."
  }
  validation {
    condition = alltrue([
      for spoke in var.spoke_configs : can(regex("^[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}$", spoke.spoke_to_ncc_peer_ip_0))
    ])
    error_message = "Each spoke_to_ncc_peer_ip_0 must be a valid IP address."
  }
  validation {
    condition = alltrue([
      for spoke in var.spoke_configs : can(cidrhost(spoke.ncc_to_spoke_ip_range_1, 0))
    ])
    error_message = "Each ncc_to_spoke_ip_range_1 must be a valid CIDR range."
  }
  validation {
    condition = alltrue([
      for spoke in var.spoke_configs : can(regex("^[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}$", spoke.spoke_to_ncc_peer_ip_1))
    ])
    error_message = "Each spoke_to_ncc_peer_ip_1 must be a valid IP address."
  }
}

# Whether to deploy a test VM in the NCC hub
variable "deploy_test_vm" {
  description = "Whether to deploy a test VM in the NCC hub in Phase 1"
  type        = bool
  default     = true
}

# Machine type for the NCC hub test VM
variable "test_vm_machine_type" {
  description = "Machine type for the NCC hub test VM in Phase 1"
  type        = string
  default     = "e2-micro"
}

# Disk image for the NCC hub test VM
variable "test_vm_image" {
  description = "Disk image for the NCC hub test VM in Phase 1"
  type        = string
  default     = "debian-cloud/debian-11"
}

variable "deploy_phase2" {
  description = "Whether to deploy phase 2 resources (VPN tunnels, NCC spoke, etc.)"
  type        = bool
  default     = false
}