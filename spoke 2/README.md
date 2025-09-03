# NCC Spoke Terraform Project

This project implements a spoke in a hub-and-spoke network architecture on Google Cloud Platform (GCP) using Terraform. The spoke connects to a central hub that manages connectivity between multiple spokes.

## Overview

The spoke project creates a VPC, subnet, HA VPN Gateway, and Cloud Router in a dedicated GCP project, connecting to a central hub via VPN tunnels. A shared Google Cloud Storage (GCS) bucket stores secrets for secure hub-spoke communication. The spoke relies on hub outputs from its Phase 1 deployment and requires coordination with the hub for Phase 2 and Phase 3.

## Deployment Workflow

The deployment is split into three phases to ensure proper setup and connectivity:

### Phase 1: Core Infrastructure
Deploy with `deploy_phase2 = false` and `deploy_phase3 = false` in `terraform.tfvars`:
- Spoke VPC, subnet, HA VPN Gateway, Cloud Router
- IAM roles and permissions
- Optional test VM

**Prerequisite**: Hub must complete Phase 1 deployment first.

### Phase 2: VPN Connectivity
After Phase 1 is complete for both hub and spoke, set `deploy_phase2 = true`:
- VPN tunnels between spoke and hub
- BGP peering configurations
- Firewall rules for VPN and BGP traffic

### Phase 3: Spoke-to-Spoke Communication
After Phase 2 is complete and hub has generated `all_spoke_cidrs` output, set `deploy_phase3 = true`:
- Dynamic firewall rules for spoke-to-spoke communication
- Requires hub's `all_spoke_cidrs` output containing all spoke subnet CIDRs

## Dependencies

* **Terraform:** Version `>= 1.0.0`
  * `hashicorp/google` provider, version `~> 6.0` (for managing GCP resources)

* **GCP Project:** Dedicated project for the spoke (`spoke_project_id`)

* **Service Accounts:**
  - Spoke service account with appropriate roles in spoke project
  - Hub service account requires `roles/compute.networkUser` in spoke project

* **GCS Buckets:**
  - Spoke state bucket (e.g., `walid-spoke-a-backend`)
  - Hub state bucket (`walid-hub-backend`) for accessing hub outputs
  - Shared secrets bucket (`walid-secrets-backend`)

## Input Variables

| Variable Name | Description | Type | Required |
|---------------|-------------|------|----------|
| prefix | Prefix for resource names to ensure uniqueness in the spoke project | string | Yes |
| spoke_project_id | GCP project ID for the spoke project | string | Yes |
| spoke_region | GCP region for spoke resources (e.g., us-central1) | string | Yes |
| spoke_subnet_cidr | CIDR range for the spoke subnet, used in Phase 1 for VPC creation | string | Yes |
| spoke_asn | BGP ASN for the spoke Cloud Router, used for BGP peering with the hub | number | Yes |
| spoke_credentials_path | Path to the GCP credentials JSON file for the spoke project | string | Yes |
| spoke_statefile_bucket_name | GCS bucket where the Phase 1 state for this spoke is stored | string | Yes |
| spoke_name | Name identifier for the spoke (used in state lookups and resource naming) | string | Yes |
| hub_service_account | Service account email for the NCC hub project, used for IAM and resource access | string | Yes |
| deploy_test_vm | Whether to deploy a test VM in the spoke in Phase 1 | bool | No |
| test_vm_machine_type | Machine type for the spoke test VM in Phase 1 | string | No |
| test_vm_image | Disk image for the spoke test VM in Phase 1 | string | No |
| gcs_bucket_name | Name of the GCS bucket containing shared secrets for hub and spoke connectivity | string | Yes |
| hub_state_bucket_name | GCS bucket where the hub's Phase 1 state is stored | string | Yes |
| hub_prefix | Prefix for the hub (used to locate its state in GCS) | string | Yes |
| spoke_to_ncc_ip_range_0 | IP range for the spoke-to-hub VPN tunnel 0 interface | string | Yes |
| spoke_to_ncc_ip_range_1 | IP range for the spoke-to-hub VPN tunnel 1 interface | string | Yes |
| ncc_to_spoke_peer_ip_0 | Hub-side BGP peer IP address for tunnel 0 | string | Yes |
| ncc_to_spoke_peer_ip_1 | Hub-side BGP peer IP address for tunnel 1 | string | Yes |
| deploy_phase2 | Whether to deploy phase 2 resources (VPN tunnels, router interfaces, etc.) | bool | No |
| deploy_phase3 | Whether to deploy phase 3 resources (spoke-to-spoke firewall rules) | bool | No |

## Hub Dependencies

- **Phase 1**: Requires hub outputs (`ncc_subnet_cidr`, `ncc_asn`, `ncc_vpn_gateway_id`)
- **Phase 2**: Establishes VPN connectivity to hub
- **Phase 3**: Requires hub's `all_spoke_cidrs` output for spoke-to-spoke communication

## Destruction Workflow

To safely delete the spoke infrastructure:

1. **First**: Disable Phase 3 (spoke-to-spoke)
   ```bash
   terraform apply -var="deploy_phase2=true" -var="deploy_phase3=false"
   ```

2. **Then**: Disable Phase 2 (VPN connectivity)
   ```bash
   terraform apply -var="deploy_phase2=false" -var="deploy_phase3=false"
   ```

3. **Finally**: Destroy all resources
   ```bash
   terraform destroy
   ```

> **Important**: The spoke's Phase 2 deployment depends on hub state files. Always disable Phase 2 in hub before destroying the spoke.

### **Critical Destruction Notice**

Phase 2 and Phase 3 resources have implicit cross-project dependencies through Terraform remote state references. The hub's Phase 2 deployment depends on spoke state data, and spokes' Phase 2/3 deployments depend on hub state data. 

**For Destruction:**
- **Phase 3 must be destroyed before Phase 2** across all spokes
- **Phase 2 must be destroyed simultaneously** across hub and all spokes
- **Phase 1 can be destroyed independently** after Phase 2 is fully removed

If you destroy Phase 1 resources before Phase 2, Terraform will be unable to properly destroy Phase 2 resources due to missing state dependencies, requiring you to:
1. Redeploy Phase 1 resources
2. Destroy Phase 2 resources 
3. Finally destroy Phase 1 resources

**Never delete state files before running `terraform destroy`**

Always follow the destruction order: Phase 3 → Phase 2 → Phase 1

## Deployment Sequence

Always deploy in this order:
1. Hub Phase 1
2. Spoke Phase 1  
3. Hub Phase 2
4. Spoke Phase 2
5. Hub Phase 3 (generates `all_spoke_cidrs`)
6. Spoke Phase 3 (consumes `all_spoke_cidrs`)

This ensures proper dependency resolution and successful connectivity establishment.