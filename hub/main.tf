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
    bucket      = "walid-hub-backend"
    prefix      = "hub-state"
    credentials = "../../../G-secrets/ncc-project-467401-b10d53e43df4.json"
  }
}

provider "google" {
  project     = var.ncc_project_id
  region      = var.ncc_region
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