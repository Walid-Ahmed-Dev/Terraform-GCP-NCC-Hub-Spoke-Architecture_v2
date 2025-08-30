# NCC Hub and Spoke Collaborative Configuration

This repository provides a Terraform configuration for deploying a Google Cloud Platform (GCP) Network Connectivity Center (NCC) hub-and-spoke architecture, with separate hub and spoke projects for improved team collaboration. It builds on the proof-of-concept from [Walid-Ahmed-Dev/Terraform-GCP-NCC-Hub-Spoke-Architecture](https://github.com/Walid-Ahmed-Dev/Terraform-GCP-NCC-Hub-Spoke-Architecture), introducing a two-phase deployment process and GCS-based state management.

## Structure
- `hub/`: Contains the Terraform configuration for the NCC hub, including VPC, subnet, HA VPN Gateway, Cloud Router, and NCC hub resources. See `hub/README.md` for details.
- `spoke/`: Contains the Terraform configuration for a single spoke, including VPC, subnet, HA VPN Gateway, and Cloud Router. See `spoke/README.md` for details.

## Features
- Separate hub and spoke configurations for independent management.
- Two-phase deployment: Phase 1 for core resources, Phase 2 for VPN tunnels and BGP peering.
- GCS buckets for state (`walid-gcs-backend` for hub, `walid-gcs-backend2` for spoke) and shared secrets (`walid-gcs-backend3`).
- Detailed READMEs with input tables, dependencies, and deletion instructions.
- Support for multiple spokes via the hub’s `spoke_configs` variable.

## Getting Started
1. Configure the hub project in `hub/terraform.tfvars` and deploy Phase 1 (`deploy_phase2 = false`).
2. Configure the spoke project in `spoke/terraform.tfvars` using hub outputs and deploy Phase 1.
3. Enable Phase 2 (`deploy_phase2 = true`) for both hub and spoke to establish VPN connectivity.
4. Refer to `hub/README.md` and `spoke/README.md` for detailed instructions.

## Inspiration
This project is inspired by the [Walid-Ahmed-Dev/Terraform-GCP-NCC-Hub-Spoke-Architecture](https://github.com/Walid-Ahmed-Dev/Terraform-GCP-NCC-Hub-Spoke-Architecture) repository, which provided a monolith and modular PoC. This configuration enhances it by splitting hub and spoke for collaboration and adding a phased deployment approach.

## Contributing
Contributions are welcome! Please follow the conventions in `hub/README.md` and `spoke/README.md`, including lowercase naming, separate `variables.tf` and `outputs.tf`, and input validation.

# NCC Hub and Spoke Terraform Project

This project implements a hub-and-spoke network architecture on Google Cloud Platform (GCP) using Terraform. The hub project is designed to manage a central hub that connects to multiple spokes, while the spoke project is tailored for a single spoke connecting to the hub. The infrastructure is deployed in two phases to ensure proper setup and connectivity.

## Overview

The hub-and-spoke model centralizes network management in the hub, which facilitates connectivity to one or more spoke projects. The hub includes a VPC, subnet, HA VPN Gateway, Cloud Router, and Network Connectivity Center (NCC) hub. Each spoke has its own VPC, subnet, HA VPN Gateway, and Cloud Router, connected to the hub via VPN tunnels and NCC spokes. A shared Google Cloud Storage (GCS) bucket stores secrets for secure communication.

## Hub and Spoke Architecture
```
                         +---------------------------------+
                         |          NCC Hub Project        |
                         |                                 |
                         |  +--------------------------+   |
                         |  |        NCC Hub VPC       |   |
                         |  |                          |   |
                         |  |  +-------------------+   |   |
                         |  |  |  NCC Hub Subnet   |   |   |
                         |  |  +-------------------+   |   |
                         |  |                          |   |
                         |  |  +-------------------+   |   |
                         |  |  | HA VPN Gateway     |   |   |
                         |  |  +-------------------+   |   |
                         |  |                          |   |
                         |  |  +-------------------+   |   |
                         |  |  |  Cloud Router      |   |   |
                         |  |  +-------------------+   |   |
                         |  |                          |   |
                         |  |  +-------------------+   |   |
                         |  |  |  NCC Hub          |   |   |
                         |  |  +-------------------+   |   |
                         |  +--------------------------+   |
                         |                                 |
                         |  +-------------------+         |
                         |  |  GCS Bucket       |         |
                         |  | (Shared Secrets)  |         |
                         |  +-------------------+         |
                         +---------------------------------+
                                  |          |
                                  | VPN      | VPN
                                  | Tunnels  | Tunnels
                                  |          |
                 +----------------+          +----------------+
                 |                                   |
     +-----------------------+            +-----------------------+
     |   Spoke A Project     |            |   Spoke B Project     |
     |                       |            |                       |
     |  +-----------------+  |            |  +-----------------+  |
     |  | Spoke A VPC     |  |            |  | Spoke B VPC     |  |
     |  |                 |  |            |  |                 |  |
     |  |  +-----------+  |  |            |  |  +-----------+  |  |
     |  |  |  Subnet   |  |  |            |  |  |  Subnet   |  |  |
     |  |  +-----------+  |  |            |  |  +-----------+  |  |
     |  |                 |  |            |  |                 |  |
     |  |  +-----------+  |  |            |  |  +-----------+  |  |
     |  |  | HA VPN    |  |  |            |  |  | HA VPN    |  |  |
     |  |  | Gateway   |  |  |            |  |  | Gateway   |  |  |
     |  |  +-----------+  |  |            |  |  +-----------+  |  |
     |  |                 |  |            |  |                 |  |
     |  |  +-----------+  |  |            |  |  +-----------+  |  |
     |  |  | Cloud     |  |  |            |  |  | Cloud     |  |  |
     |  |  | Router    |  |  |            |  |  | Router    |  |  |
     |  |  +-----------+  |  |            |  |  +-----------+  |  |
     |  +-----------------+  |            |  +-----------------+  |
     +-----------------------+            +-----------------------+
```
## Deployment Workflow

The deployment is split into two phases to ensure the hub and spoke infrastructure are set up correctly:

### Phase 1:
Deploy the hub and spoke resources with `deploy_phase2 = false` in the `terraform.tfvars` files for both hub and spoke. This phase sets up:

- **Hub**: VPC, subnet, HA VPN Gateway, Cloud Router, NCC hub, GCS bucket for shared secrets, IAM roles, and an optional test VM.  
- **Spoke**: VPC, subnet, HA VPN Gateway, Cloud Router, IAM roles, and an optional test VM.  
- Shared secrets are generated and stored in the GCS bucket for VPN connectivity.

### Phase 2:
After Phase 1 is complete, set `deploy_phase2 = true` in both the hub and spoke `terraform.tfvars` files and redeploy. This phase establishes:

- VPN tunnels between the hub and each spoke.  
- NCC spoke resources linking the hub to each spoke.  
- BGP peering configurations for routing.  
- Firewall rules to allow VPN, BGP, and spoke-to-spoke traffic.

**Important**: Always deploy with `deploy_phase2 = false` first to create the foundational infrastructure (Phase 1). Only after confirming Phase 1 is successfully deployed for both hub and spoke should you set `deploy_phase2 = true` to establish VPN connectivity and NCC spoke resources (Phase 2). Spoke deployments depend on the hub's Phase 1 outputs, and hub Phase 2 deployment depends on spoke outputs.

## Dependencies

* **Terraform:** Version `>= 1.0.0` 
  * `hashicorp/google` provider, version `~> 6.0` (for managing GCP resources)
  * `hashicorp/random(Hub only)` provider, version `~> 3.0` (for generating random IDs or names) 
- **Google Cloud SDK**: Required for interacting with GCP APIs and managing credentials.  

### GCP Projects:

- A dedicated GCP project for the hub (`ncc_project_id`).  
- A separate GCP project for each spoke (`spoke_project_id`).  

### Service Accounts:

- **Hub service account** with `roles/compute.networkAdmin` and `roles/networkconnectivity.hubAdmin` in the hub project, and `roles/compute.networkUser` and `roles/storage.objectAdmin` in the spoke project.  
- **Spoke service account** with `roles/compute.networkUser` and `roles/networkconnectivity.spokeAdmin` in the hub project, and `roles/storage.objectViewer` on the shared secrets GCS bucket.  

### GCS Buckets:

- Hub Terraform state bucket (`walid-gcs-backend`).  
- Spoke Terraform state bucket (`walid-gcs-backend2`).  
- Shared secrets bucket (`walid-gcs-backend3`).  

### Hub-Spoke Dependencies:

- **Spoke Phase 1** requires hub outputs (`ncc_subnet_cidr`, `ncc_asn`, `ncc_vpn_gateway_id`) from hub Phase 1.  
- **Hub Phase 2** requires spoke outputs (`spoke_subnet_cidr`, `spoke_asn`, `spoke_vpn_gateway_id`) from spoke Phase 1, accessed via the spoke state file in `walid-gcs-backend2` with prefix `spoke-a-state`.  
- **Spoke Phase 2** requires hub outputs (`ncc_subnet_cidr`, `ncc_asn`, `ncc_vpn_gateway_id`) from hub Phase 1, accessed via the hub state file in `walid-gcs-backend` with prefix `hub-state`.

### Credentials:
JSON key files for hub (`ncc-project-467401-210df7f1e23a.json`) and spoke (`pelagic-core-467122-q4-25d0b2aa49f2.json`) projects.

## Input Variables

### Hub Input Variables

The following table lists the input variables for the hub project, as defined in `hub/variables.tf` and `hub/ncc-hub-module/variables.tf`.

| Variable Name | Description | Type | Default Value | Required |
|---------------|-------------|------|----------------|----------|
| prefix | Prefix for resource names to ensure uniqueness in the NCC hub project | string | walid | Yes |
| ncc_project_id | GCP project ID for the NCC hub project | string | None | Yes |
| ncc_region | GCP region for NCC hub resources (e.g., us-central1) | string | us-central1 | Yes |
| ncc_subnet_cidr | CIDR range for the NCC hub subnet, used in Phase 1 for VPC creation | string | 10.190.0.0/24 | Yes |
| ncc_asn | BGP ASN for the NCC hub Cloud Router, used in Phase 1 and 2 | number | 64512 | Yes |
| ncc_credentials_path | Path to the GCP credentials JSON file for the NCC hub project | string | None | Yes |
| ncc_hub_service_account | Service account email for the NCC hub project | string | None | Yes |
| ncc-hub_statefile_bucket_name | Name of the GCS bucket for

# Deletion Disclaimer

The spoke and hub projects have interdependencies due to their use of `terraform_remote_state` data sources to access each other’s outputs during Phase 2 deployment:

- **Spoke Dependency**: The spoke’s Phase 2 configuration uses  
  `data "terraform_remote_state" "hub"`  
  to retrieve hub outputs (`ncc_subnet_cidr`, `ncc_asn`, `ncc_vpn_gateway_id`) from the hub’s state file in `walid-gcs-backend` with prefix `hub-state`.

- **Hub Dependency**: The hub’s Phase 2 configuration uses  
  `data "terraform_remote_state" "spoke"`  
  to retrieve spoke outputs (`spoke_subnet_cidr`, `spoke_asn`, `spoke_vpn_gateway_id`) from the spoke’s state file in `walid-gcs-backend2` with prefix `spoke-a-state`.

These dependencies mean that deleting one project’s infrastructure can cause errors in the other if not handled correctly, as Terraform will attempt to access state files that may no longer exist or reference resources that have been deleted.

---

## Recommended Deletion Workflow

To safely delete the hub and spoke infrastructure:

### Option 1: Simultaneous Deletion

Delete both hub and spoke infrastructure at the same time to avoid dependency issues:

```bash
cd hub
terraform destroy

cd spoke
terraform destroy
````

Run these commands in parallel or in quick succession to ensure state files remain accessible.

---

### Option 2: Sequential Deletion with Redeployment

If you accidentally delete one project (e.g., the hub), redeploy it with `deploy_phase2 = false` to restore only Phase 1 resources:

```bash
cd hub
# Update terraform.tfvars to set deploy_phase2 = false
terraform apply
```

Then, destroy the other project (e.g., the spoke) first, as it depends on hub outputs:

```bash
cd spoke
terraform destroy
```

Finally, destroy the redeployed project (e.g., the hub):

```bash
cd hub
terraform destroy
```

This ensures the hub’s Phase 1 state is available when destroying the spoke, and vice versa.

---

> **Important**:
> Never delete the state files (`walid-gcs-backend` or `walid-gcs-backend2`) before running `terraform destroy`, as Terraform relies on them to track resources.
> Always destroy **Phase 2 resources** (`deploy_phase2 = true`) before **Phase 1 resources**, as Phase 2 depends on Phase 1 outputs in both projects.
