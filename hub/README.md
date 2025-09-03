# NCC Hub Terraform Project

This project implements the hub component of a hub-and-spoke network architecture on Google Cloud Platform (GCP) using Terraform. The hub centralizes network management and connectivity to multiple spoke projects.

## Overview

The hub project creates a VPC, subnet, HA VPN Gateway, Cloud Router, and Network Connectivity Center (NCC) hub in a dedicated GCP project. It manages connectivity to multiple spokes via VPN tunnels and provides centralized routing through BGP peering. The infrastructure is deployed in three phases to ensure proper setup and connectivity.

## Deployment Workflow

The deployment is split into three phases to ensure proper setup and connectivity:

### Phase 1: Core Infrastructure
Deploy with `deploy_phase2 = false` and `deploy_phase3 = false` in `terraform.tfvars`:
- VPC, subnet, HA VPN Gateway, Cloud Router
- NCC hub resource
- GCS bucket for shared secrets
- IAM roles and permissions
- Optional test VM

### Phase 2: VPN Connectivity
After Phase 1 is complete for both hub and all spokes, set `deploy_phase2 = true`:
- VPN tunnels to each spoke
- BGP peering configurations
- NCC spoke resources linking hub to spokes
- Firewall rules for VPN and BGP traffic

### Phase 3: Spoke-to-Spoke Output Generation
After Phase 2 is complete, set `deploy_phase3 = true`:
- Generates `all_spoke_cidrs` output containing all spoke subnet CIDRs
- Required for spoke Phase 3 deployment
- Verify output with: `terraform output all_spoke_cidrs` (should show `["10.191.1.0/24", "10.191.2.0/24"]`)

## Dependencies

* **Terraform:** Version `>= 1.0.0`
  * `hashicorp/google` provider, version `~> 6.0`
  * `hashicorp/random` provider, version `~> 3.0`

* **GCP Project:** Dedicated project for the hub (`ncc_project_id`)

* **Service Accounts:**
  - Hub service account with `roles/compute.networkAdmin` and `roles/networkconnectivity.hubAdmin` in hub project
  - Spoke service accounts require appropriate permissions in hub project

* **GCS Buckets:**
  - Hub state bucket (`walid-hub-backend`)
  - Shared secrets bucket (`walid-secrets-backend`)

## Input Variables

| Variable Name | Description | Type | Required |
|---------------|-------------|------|----------|
| prefix | Prefix for resource names to ensure uniqueness in the NCC hub project | string | Yes |
| ncc_project_id | GCP project ID for the NCC hub project | string | Yes |
| ncc_region | GCP region for NCC hub resources (e.g., us-central1) | string | Yes |
| ncc_subnet_cidr | CIDR range for the NCC hub subnet | string | Yes |
| ncc_asn | BGP ASN for the NCC hub Cloud Router | number | Yes |
| ncc_credentials_path | Path to the GCP credentials JSON file for the NCC hub project | string | Yes |
| ncc_hub_service_account | Service account email for the NCC hub project | string | Yes |
| ncc-hub_statefile_bucket_name | GCS bucket for hub Terraform state storage | string | Yes |
| gcs_bucket_name | GCS bucket for shared secrets | string | Yes |
| spoke_configs | List of spoke configurations for IAM and VPN connectivity | list(object) | No |
| deploy_test_vm | Whether to deploy a test VM in the NCC hub | bool | No |
| test_vm_machine_type | Machine type for the NCC hub test VM | string | No |
| test_vm_image | Disk image for the NCC hub test VM | string | No |
| deploy_phase2 | Whether to deploy phase 2 resources (VPN tunnels, NCC spoke, etc.) | bool | No |
| deploy_phase3 | Whether to deploy phase 3 outputs (all_spoke_cidrs) | bool | No |

### spoke_configs Object Structure

Each object in the `spoke_configs` list contains the following properties:

| Property | Description | Type |
|----------|-------------|------|
| name | Spoke name identifier | string |
| spoke_statefile_bucket_name | GCS bucket name for spoke Terraform state | string |
| spoke_state_prefix | Prefix for spoke state file in GCS bucket | string |
| service_account | Spoke service account email | string |
| ncc_to_spoke_ip_range_0 | CIDR range for NCC to Spoke tunnel 0 | string |
| spoke_to_ncc_peer_ip_0 | Peer IP address for Spoke to NCC tunnel 0 | string |
| ncc_to_spoke_ip_range_1 | CIDR range for NCC to Spoke tunnel 1 | string |
| spoke_to_ncc_peer_ip_1 | Peer IP address for Spoke to NCC tunnel 1 | string |

## Hub Dependencies

- **Phase 1**: Provides outputs for spoke consumption (`ncc_subnet_cidr`, `ncc_asn`, `ncc_vpn_gateway_id`)
- **Phase 2**: Requires spoke outputs (`spoke_subnet_cidr`, `spoke_asn`, `spoke_vpn_gateway_id`) from all spoke state files
- **Phase 3**: Provides `all_spoke_cidrs` output for spoke-to-spoke communication (consumed by spokes)

## Outputs

The hub module provides these outputs for spoke consumption:

- `ncc_subnet_cidr`: Hub subnet CIDR range
- `ncc_asn`: Hub BGP ASN
- `ncc_vpn_gateway_id`: Hub VPN gateway ID
- `all_spoke_cidrs`: List of all spoke subnet CIDRs (for Phase 3, requires `deploy_phase3 = true`)

## Destruction Workflow

To safely delete the hub infrastructure:

1. **First**: Ensure all spokes have Phase 3 disabled and Phase 2 disabled
2. **Then**: Destroy hub resources:

```bash
cd hub
terraform destroy
```

> **Important**: The hub's Phase 2 deployment depends on spoke state files. Always disable Phase 2 in spokes before destroying the hub.

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

---