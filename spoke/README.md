# NCC Spoke Terraform Project

This project implements a spoke in a hub-and-spoke network architecture on Google Cloud Platform (GCP) using Terraform. The spoke project is designed for a single spoke that connects to a central hub, which manages connectivity to multiple spokes. The infrastructure is deployed in two phases to ensure proper setup and connectivity.

## Overview

The spoke project creates a VPC, subnet, HA VPN Gateway, and Cloud Router in a dedicated GCP project, connecting to a central hub via VPN tunnels. A shared Google Cloud Storage (GCS) bucket stores secrets for secure hub-spoke communication. The spoke relies on hub outputs from its Phase 1 deployment and requires coordination with the hub for Phase 2.

## Hub and Spoke Architecture

Below is a text-based illustration of the hub-and-spoke architecture, highlighting the spoke’s role:

```
                         +---------------------------------+
                         |          NCC Hub Project        |
                         |                                 |
                         |  +--------------------------+   |
                         |  |        NCC Hub VPC       |   |
                         |  |  +-------------------+   |   |
                         |  |  |  NCC Hub Subnet   |   |   |
                         |  |  +-------------------+   |   |
                         |  |  +-------------------+   |   |
                         |  |  | HA VPN Gateway     |   |   |
                         |  |  +-------------------+   |   |
                         |  |  +-------------------+   |   |
                         |  |  |  Cloud Router      |   |   |
                         |  |  +-------------------+   |   |
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
                                  | VPN
                                  | Tunnels
                                  |
                 +----------------+
                 |
     +-----------------------+
     |   Spoke A Project     |
     |                       |
     |  +-----------------+  |
     |  | Spoke A VPC     |  |
     |  |                 |  |
     |  |  +-----------+  |  |
     |  |  |  Subnet   |  |  |
     |  |  +-----------+  |  |
     |  |                 |  |
     |  |  +-----------+  |  |
     |  |  | HA VPN    |  |  |
     |  |  | Gateway   |  |  |
     |  |  +-----------+  |  |
     |  |                 |  |
     |  |  +-----------+  |  |
     |  |  | Cloud     |  |  |
     |  |  | Router    |  |  |
     |  |  +-----------+  |  |
     |  +-----------------+  |
     +-----------------------+
```
## Deployment Workflow

The deployment is split into two phases to ensure proper setup and connectivity:

### Phase 1

Deploy the spoke resources with `deploy_phase2 = false` in `terraform.tfvars`. This phase sets up:

- Spoke VPC, subnet, HA VPN Gateway, Cloud Router, IAM roles, and an optional test VM.
- The hub must complete its Phase 1 deployment first, as the spoke requires hub outputs (`ncc_subnet_cidr`, `ncc_asn`, `ncc_vpn_gateway_id`).

### Phase 2

After Phase 1 is complete for both hub and spoke, set `deploy_phase2 = true` in `terraform.tfvars` and redeploy. This phase establishes:

- VPN tunnels between the spoke and hub.
- BGP peering configurations for routing.
- Firewall rules to allow VPN, BGP, and spoke-to-spoke traffic.

**Important**: Always deploy with `deploy_phase2 = false` first to create the foundational infrastructure (Phase 1). Only after confirming Phase 1 is successfully deployed for both hub and spoke should you set `deploy_phase2 = true` to establish VPN connectivity (Phase 2). The spoke depends on the hub’s Phase 1 outputs, and the hub’s Phase 2 deployment depends on spoke outputs.

## Dependencies

* **Terraform Providers:**
* **Terraform:** Version `>= 1.0.0` 
  * `hashicorp/google` provider, version `~> 6.0` (for managing GCP resources)
- **Google Cloud SDK**: Required for interacting with GCP APIs and managing credentials.

### GCP Projects:

- A dedicated GCP project for the spoke (`spoke_project_id`).
- A hub project with Phase 1 completed, providing outputs (`ncc_subnet_cidr`, `ncc_asn`, `ncc_vpn_gateway_id`).

### Service Accounts:

- **Spoke service account** with `roles/compute.networkUser` and `roles/networkconnectivity.spokeAdmin` in the hub project, and `roles/storage.objectViewer` on the shared secrets GCS bucket (`walid-gcs-backend3`).
- **Hub service account** with `roles/compute.networkUser` and `roles/storage.objectAdmin` in the spoke project.

### GCS Buckets:

- **Spoke Terraform state bucket**: `walid-gcs-backend2` with prefix `spoke-a-state`.
- **Hub Terraform state bucket**: `walid-gcs-backend` with prefix `hub-state` for accessing hub outputs.
- **Shared secrets bucket**: `walid-gcs-backend3` for VPN shared secrets.

### Hub-Spoke Dependencies:

- **Spoke Phase 1** requires hub outputs from `walid-gcs-backend` with prefix `hub-state`.
- **Hub Phase 2** requires spoke outputs (`spoke_subnet_cidr`, `spoke_asn`, `spoke_vpn_gateway_id`) from `walid-gcs-backend2` with prefix `spoke-a-state`.

- **Credentials**: JSON key file for the spoke project (`pelagic-core-467122-q4-25d0b2aa49f2.json`).

## Input Variables

The following table lists the input variables for the spoke project, as defined in `spoke/variables.tf` and `spoke/ncc-spoke-module/variables.tf`.

| Variable Name               | Description                                                               | Type    | Default Value              | Required |
|----------------------------|---------------------------------------------------------------------------|---------|----------------------------|----------|
| prefix                     | Prefix for resource names to ensure uniqueness in the spoke project       | string  | walid                      | Yes      |
| spoke_project_id           | GCP project ID for the spoke project                                      | string  | None                       | Yes      |
| spoke_region               | GCP region for spoke resources (e.g., asia-northeast1)                    | string  | us-central1                | Yes      |
| spoke_subnet_cidr          | CIDR range for the spoke subnet, used in Phase 1 for VPC creation         | string  | None                       | Yes      |
| spoke_asn                  | BGP ASN for the spoke Cloud Router, used for BGP peering with the hub     | number  | 64513                      | Yes      |
| spoke_credentials_path     | Path to the GCP credentials JSON file for the spoke project               | string  | None                       | Yes      |
| spoke_statefile_bucket_name| GCS bucket where the Phase 1 state for this spoke is stored               | string  | None                       | Yes      |
| spoke_name                 | Name identifier for the spoke (used in state lookups and resource naming) | string  | None                       | Yes      |
| hub_service_account        | Service account email for the NCC hub project                             | string  | None                       | Yes      |
| gcs_bucket_name            | Name of the GCS bucket containing shared secrets for hub and spoke        | string  | None                       | Yes      |
| hub_state_bucket_name      | GCS bucket where the hub's Phase 1 state is stored                        | string  | None                       | Yes      |
| hub_prefix                 | Prefix for the hub (used to locate its state in GCS)                      | string  | None                       | Yes      |
| spoke_to_ncc_ip_range_0    | IP range for the spoke-to-hub VPN tunnel 0 interface                      | string  | None                       | Yes      |
| ncc_to_spoke_peer_ip_0     | Hub-side BGP peer IP address for tunnel 0                                 | string  | None                       | Yes      |
| spoke_to_ncc_ip_range_1    | IP range for the spoke-to-hub VPN tunnel 1 interface                      | string  | None                       | Yes      |
| ncc_to_spoke_peer_ip_1     | Hub-side BGP peer IP address for tunnel 1                                 | string  | None                       | Yes      |
| deploy_test_vm             | Whether to deploy a test VM in the spoke in Phase 1                       | bool    | true                       | No       |
| test_vm_machine_type       | Machine type for the spoke test VM in Phase 1                             | string  | e2-micro                   | No       |
| test_vm_image              | Disk image for the spoke test VM in Phase 1                               | string  | debian-cloud/debian-11     | No       |
| deploy_phase2              | Whether to deploy Phase 2 resources (VPN tunnels, router interfaces, etc.)|

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