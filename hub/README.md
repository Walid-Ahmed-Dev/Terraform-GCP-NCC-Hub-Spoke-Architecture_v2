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
Deploy the hub and spoke resources with `deploy_phase2 = false` in the `terraform.tfvars` file. This phase sets up:

- **Hub:** VPC, subnet, HA VPN Gateway, Cloud Router, NCC hub, GCS bucket for shared secrets, IAM roles, and an optional test VM.
- **Spoke:** VPC, subnet, HA VPN Gateway, Cloud Router, and IAM roles.

Shared secrets are generated and stored in the GCS bucket for VPN connectivity.

### Phase 2:
After Phase 1 is complete, set `deploy_phase2 = true` in the hub's `terraform.tfvars` file and redeploy. This phase establishes:

- VPN tunnels between the hub and each spoke.
- NCC spoke resources linking the hub to each spoke.
- BGP peering configurations for routing.
- Firewall rules to allow VPN, BGP, and spoke-to-spoke traffic.

> **Important:** Always deploy with `deploy_phase2 = false` first to create the foundational infrastructure (Phase 1). Only after confirming Phase 1 is successfully deployed should you set `deploy_phase2 = true` to establish VPN connectivity and NCC spoke resources (Phase 2). Spoke deployments depend on the hub's Phase 1 outputs.

## Dependencies

* **Terraform Providers:**
* **Terraform:** Version `>= 1.0.0` 
  * `hashicorp/google` provider, version `~> 6.0` (for managing GCP resources)
  * `hashicorp/random` provider, version `~> 3.0` (for generating random IDs or names)
- **Google Cloud SDK:** Required for interacting with GCP APIs and managing credentials.
- **GCP Projects:**
  - A dedicated GCP project for the hub (`ncc_project_id`).
  - Separate GCP projects for each spoke (referenced in `spoke_configs`).
- **Service Accounts:**
  - Hub service account with `roles/compute.networkAdmin` and `roles/networkconnectivity.hubAdmin`.
  - Spoke service accounts with `roles/compute.networkUser` and `roles/networkconnectivity.spokeAdmin` on the hub project, and `roles/storage.objectViewer` on the shared secrets GCS bucket.
- **GCS Buckets:**
  - A bucket for Terraform state storage (`walid-gcs-backend` for hub, specified in `main.tf`).
  - A bucket for shared secrets (`walid-gcs-backend3` for hub, specified in `terraform.tfvars`).
- **Hub-Spoke Dependencies:**
  - Spoke deployments require hub outputs (`ncc_subnet_cidr`, `ncc_asn`, `ncc_vpn_gateway_id`) from Phase 1.
  - Phase 2 hub deployment depends on spoke state files (stored in `spoke_statefile_bucket_name` with `spoke_state_prefix`) for VPN tunnel and NCC spoke configurations.
- **Credentials:** A JSON key file for the hub project’s service account, specified in `ncc_credentials_path`.

## Input Variables

The following table lists the input variables for the hub project, as defined in `hub/variables.tf` and `hub/ncc-hub-module/variables.tf`. Spoke project variables are not included due to missing files but are assumed to follow a similar structure.

| Variable Name                    | Description                                                                                      | Type      | Default Value             | Required |
|----------------------------------|--------------------------------------------------------------------------------------------------|-----------|---------------------------|----------|
| prefix                           | Prefix for resource names to ensure uniqueness in the NCC hub project                           | string    | walid                     | Yes      |
| ncc_project_id                   | GCP project ID for the NCC hub project                                                          | string    | None                      | Yes      |
| ncc_region                       | GCP region for NCC hub resources (e.g., us-central1)                                            | string    | us-central1               | Yes      |
| ncc_subnet_cidr                  | CIDR range for the NCC hub subnet, used in Phase 1 for VPC creation                            | string    | 10.190.0.0/24             | Yes      |
| ncc_asn                          | BGP ASN for the NCC hub Cloud Router, used in Phase 1 and 2                                     | number    | 64512                     | Yes      |
| ncc_credentials_path            | Path to the GCP credentials JSON file for the NCC hub project                                  | string    | None                      | Yes      |
| ncc_hub_service_account         | Service account email for the NCC hub project                                                   | string    | None                      | Yes      |
| ncc-hub_statefile_bucket_name   | Name of the GCS bucket for hub Terraform state storage                                          | string    | None                      | Yes      |
| gcs_bucket_name                  | Name of the GCS bucket to store shared secrets for hub and spoke connectivity                   | string    | None                      | Yes      |
| spoke_configs                    | List of spoke configurations for IAM (Phase 1) and VPN connectivity (Phase 2)                   | list(object) | []                        | Yes      |
| deploy_test_vm                   | Whether to deploy a test VM in the NCC hub

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