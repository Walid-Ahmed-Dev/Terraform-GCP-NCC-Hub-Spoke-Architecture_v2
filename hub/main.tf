# Defining Terraform provider requirements and version constraints
terraform {
  required_version = ">= 1.0.0"
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
  backend "gcs" {
    bucket = "walid-hub-backend"
    prefix = "hub-state"
    # SECURITY NOTE: Credentials are stored OUTSIDE the project directory (../../../G-secrets/)
    # This is an intentional design choice for development workflow simplicity.
    # The path references a directory 3 levels up from the project root, ensuring credentials
    # are physically separated from the Git repository even if .gitignore fails.
    #
    # For production environments, consider:
    # - Workload Identity Federation (no credentials needed)
    # - Environment variables: export GOOGLE_APPLICATION_CREDENTIALS="/path/to/key.json"
    # - Secret management services (Google Secret Manager, HashiCorp Vault)
    #
    # If you fork this project:
    # 1. Store YOUR credentials outside your project directory
    # 2. Update this path to match your credentials location
    # 3. Verify .gitignore excludes your credentials path
    # 4. Never commit credentials to version control
    credentials = "../../../G-secrets/ncc-project-467401-b10d53e43df4.json"
  }
}

provider "google" {
  project = var.ncc_project_id
  region  = var.ncc_region
  # SECURITY NOTE: Credentials path references location OUTSIDE project directory
  # See SECURITY.md for explanation of this design pattern and production alternatives
  credentials = var.ncc_credentials_path
}

# NCC hub module 
module "ncc_hub" {
  source                        = "./modules/ncc-hub-module"
  prefix                        = var.prefix
  ncc_project_id                = var.ncc_project_id
  ncc_region                    = var.ncc_region
  ncc_subnet_cidr               = var.ncc_subnet_cidr
  ncc_asn                       = var.ncc_asn
  ncc_credentials_path          = var.ncc_credentials_path
  ncc_hub_service_account       = var.ncc_hub_service_account
  ncc-hub_statefile_bucket_name = var.ncc-hub_statefile_bucket_name
  gcs_bucket_name               = var.gcs_bucket_name
  spoke_configs                 = var.spoke_configs

  deploy_test_vm       = var.deploy_test_vm
  test_vm_machine_type = var.test_vm_machine_type
  test_vm_image        = var.test_vm_image

  deploy_phase2 = var.deploy_phase2
  deploy_phase3 = var.deploy_phase3

  providers = {
    google = google
  }
}