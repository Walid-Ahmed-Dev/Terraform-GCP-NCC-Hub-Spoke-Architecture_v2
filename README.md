# NCC Hub and Spoke Collaborative Configuration

This repository provides a Terraform configuration for deploying a Google Cloud Platform (GCP) Network Connectivity Center (NCC) hub-and-spoke architecture, with separate hub and spoke projects for improved team collaboration. It builds on the proof-of-concept from [bleeng089/Armageddon_6.5_6-2025](https://github.com/bleeng089/Armageddon_6.5_6-2025), introducing a three-phase deployment process and GCS-based state management.

## Structure
- `hub/`: Contains the Terraform configuration for the NCC hub, including VPC, subnet, HA VPN Gateway, Cloud Router, and NCC hub resources. See `hub/README.md` for details.
- `spoke/`: Contains the Terraform configuration for a single spoke, including VPC, subnet, HA VPN Gateway, and Cloud Router. See `spoke/README.md` for details.
- `spoke2/`: Contains the configuration for a second spoke (similar to spoke/).

## Features
- Separate hub and spoke configurations for independent management.
- Three-phase deployment: 
  - Phase 1: Core infrastructure (VPC, subnets, VPN gateways, routers)
  - Phase 2: VPN connectivity (tunnels, BGP peering, NCC spokes)
  - Phase 3: Spoke-to-spoke communication (firewall rules)
- GCS buckets for state management and shared secrets.
- Support for multiple spokes via the hub's `spoke_configs` variable.
- Dynamic firewall rules for spoke-to-spoke communication.

## Getting Started
1. Configure the hub project in `hub/terraform.tfvars` and deploy Phase 1 (`deploy_phase2 = false`, `deploy_phase3 = false`).
2. Configure each spoke project in `spoke/terraform.tfvars` and `spoke2/terraform.tfvars` using hub outputs and deploy Phase 1.
3. Enable Phase 2 (`deploy_phase2 = true`) for both hub and spokes to establish VPN connectivity.
4. Enable Phase 3 (`deploy_phase3 = true`) on the hub to generate the `all_spoke_cidrs` output.
5. Verify the hub outputs contain all spoke CIDRs: `terraform output all_spoke_cidrs` should show `["10.191.1.0/24", "10.191.2.0/24"]`
6. Enable Phase 3 (`deploy_phase3 = true`) on both spokes to enable spoke-to-spoke communication.
7. Refer to `hub/README.md` and `spoke/README.md` for detailed instructions.

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

## Service Account Requirements

### Hub Project Service Accounts

**Hub Service Account** (`var.ncc_hub_service_account`):
- **Required Roles in Hub Project**:
  - `roles/compute.networkAdmin` - For VPC, subnet, VPN gateway, and firewall management
  - `roles/networkconnectivity.hubAdmin` - For NCC hub administration
  - `roles/storage.admin` - For GCS bucket creation and management

**Spoke Service Accounts Access in Hub Project**:
Each spoke service account (from `var.spoke_configs`) requires:
- `roles/compute.networkUser` - For network resource access
- `roles/networkconnectivity.spokeAdmin` - For NCC spoke administration
- `roles/storage.objectViewer` - For reading shared secrets from GCS
- `roles/storage.objectAdmin` - For accessing hub state files

### Spoke Project Service Accounts

**Spoke Service Account** (created in spoke project):
- **Required Roles in Spoke Project**:
  - `roles/compute.networkAdmin` - For VPC, subnet, VPN gateway management
  - `roles/storage.admin` - For GCS bucket access

**Hub Service Account Access in Spoke Project**:
The hub service account requires:
- `roles/compute.networkUser` - For accessing spoke network resources
- `roles/storage.objectViewer` - For reading spoke state files

## GCS Bucket Requirements

### State Management Buckets

1. **Hub State Bucket** (`walid-hub-backend`):
   - Stores hub Terraform state with prefix `hub-state`
   - Requires read/write access for hub service account
   - Requires read access for spoke service accounts

2. **Spoke State Buckets** (`walid-spoke-a-backend`, `walid-spoke-b-backend`):
   - Stores spoke Terraform state with prefixes `spoke-a-state`, `spoke-b-state`
   - Requires read/write access for spoke service accounts
   - Requires read access for hub service account

### Shared Secrets Bucket

3. **Shared Secrets Bucket** (`walid-secrets-backend`):
   - Stores VPN shared secrets and configuration data
   - Requires write access for hub service account
   - Requires read access for spoke service accounts

## Service Account Key Requirements

### Terraform Provider Credentials

**Hub Deployment**:
```hcl
provider "google" {
  project     = var.ncc_project_id
  region      = var.ncc_region
  credentials = file(var.ncc_credentials_path)  # Hub service account key
  alias       = "ncc_hub"
}
```

**Spoke Deployment**:
```hcl
provider "google" {
  project     = var.spoke_project_id
  region      = var.spoke_region
  credentials = file(var.spoke_credentials_path)  # Spoke service account key
}
```

### Required Service Account Keys

1. **Hub Service Account Key**:
   - Path: `var.ncc_credentials_path` (e.g., `../../../G-secrets/ncc-project-467401-3af773551e59.json`)
   - Used by: Hub Terraform provider
   - Permissions: Full access to hub project resources

2. **Spoke Service Account Keys**:
   - Path: `var.spoke_credentials_path` (e.g., `../../../G-secrets/pelagic-core-467122-q4-25d0b2aa49f2.json`)
   - Used by: Spoke Terraform providers
   - Permissions: Full access to spoke project resources
  
## Deployment Workflow

### Phase 1: Core Infrastructure

1. **Create Service Accounts**:
   - Create hub service account in hub project with required roles
   - Create spoke service accounts in spoke projects with required roles
   - Generate and download JSON keys for all service accounts

2. **Configure GCS Buckets**:
   - Create state buckets for hub and spoke projects
   - Create shared secrets bucket
   - Configure appropriate IAM permissions

3. **Deploy Hub (Phase 1)**:
   ```bash
   cd hub
   terraform apply -var="deploy_phase2=false" -var="deploy_phase3=false"
   ```

4. **Deploy Spokes (Phase 1)**:
   ```bash
   cd spoke
   terraform apply -var="deploy_phase2=false" -var="deploy_phase3=false"
   
   cd ../spoke2
   terraform apply -var="deploy_phase2=false" -var="deploy_phase3=false"
   ```

### Phase 2: VPN Connectivity

1. **Enable Phase 2 Deployment**:
   ```bash
   # Hub
   cd hub
   terraform apply -var="deploy_phase2=true" -var="deploy_phase3=false"
   
   # Spokes
   cd spoke
   terraform apply -var="deploy_phase2=true" -var="deploy_phase3=false"
   
   cd ../spoke2
   terraform apply -var="deploy_phase2=true" -var="deploy_phase3=false"
   ```

### Phase 3: Spoke-to-Spoke Communication

1. **Enable Phase 3 on Hub** (generates all_spoke_cidrs output):
   ```bash
   cd hub
   terraform apply -var="deploy_phase2=true" -var="deploy_phase3=true"
   
   # Verify the output contains all spoke CIDRs
   terraform output all_spoke_cidrs
   # Should show: ["10.191.1.0/24", "10.191.2.0/24"]
   ```

2. **Enable Phase 3 on Spokes** (consumes all_spoke_cidrs for firewall rules):
   ```bash
   cd spoke
   terraform apply -var="deploy_phase2=true" -var="deploy_phase3=true"
   
   cd ../spoke2
   terraform apply -var="deploy_phase2=true" -var="deploy_phase3=true"
   ```

---
>**Important Deployment Order**: 
> 1. Always deploy Phase 1 first (`deploy_phase2 = false`, `deploy_phase3 = false`)
> 2. Then deploy Phase 2 (`deploy_phase2 = true`, `deploy_phase3 = false`)  
> 3. Then deploy Phase 3 on hub first (`deploy_phase2 = true`, `deploy_phase3 = true`) to generate `all_spoke_cidrs`
> 4. Finally deploy Phase 3 on spokes (`deploy_phase2 = true`, `deploy_phase3 = true`) to consume the output
>
> Spoke deployments depend on the hub's Phase 1 outputs, and hub Phase 2 deployment depends on spoke outputs. Phase 3 requires Phase 2 to be complete and the hub must generate outputs before spokes can consume them.
---

## Critical Dependencies

### Hub Dependencies
- **Phase 1**: Provides outputs for spoke consumption (`ncc_subnet_cidr`, `ncc_asn`, `ncc_vpn_gateway_id`)
- **Phase 2**: Requires spoke outputs (`spoke_subnet_cidr`, `spoke_asn`, `spoke_vpn_gateway_id`) from all spoke state files
- **Phase 3**: Provides `all_spoke_cidrs` output for spoke-to-spoke communication (consumed by spokes)

### Spoke Dependencies
- **Phase 1**: Requires hub outputs (`ncc_subnet_cidr`, `ncc_asn`, `ncc_vpn_gateway_id`)
- **Phase 2**: Establishes VPN connectivity to hub
- **Phase 3**: Requires hub's `all_spoke_cidrs` output for spoke-to-spoke communication

## Credential Management Best Practices

1. **Secure Storage**: Store service account keys in a secure location outside version control
2. **Least Privilege**: Assign only necessary permissions to each service account
3. **Key Rotation**: Regularly rotate service account keys
4. **Environment Separation**: Use different service accounts for different environments

## Dependencies

* **Terraform:** Version `>= 1.0.0` 
  * `hashicorp/google` provider, version `~> 6.0` (for managing GCP resources)
  * `hashicorp/random` provider (Hub only), version `~> 3.0` (for generating random IDs)
- **Google Cloud SDK**: Required for interacting with GCP APIs and managing credentials.  

### GCP Projects:

- A dedicated GCP project for the hub (`ncc_project_id`).  
- Separate GCP projects for each spoke (`spoke_project_id`).  

### Service Accounts:

- **Hub service account** with appropriate roles in hub and spoke projects
- **Spoke service accounts** with appropriate roles in spoke and hub projects

### GCS Buckets:

- Hub Terraform state bucket (`walid-hub-backend`)  
- Spoke Terraform state buckets (`walid-spoke-a-backend`, `walid-spoke-b-backend`)  
- Shared secrets bucket (`walid-secrets-backend`)  

### Hub-Spoke Dependencies:

- **Spoke Phase 1** requires hub outputs (`ncc_subnet_cidr`, `ncc_asn`, `ncc_vpn_gateway_id`) from hub Phase 1.  
- **Hub Phase 2** requires spoke outputs (`spoke_subnet_cidr`, `spoke_asn`, `spoke_vpn_gateway_id`) from spoke Phase 1.  
- **Spoke Phase 2** requires hub outputs from hub Phase 1.  
- **Spoke Phase 3** requires hub outputs (`all_spoke_cidrs`) from hub Phase 3.

### Credentials:
JSON key files for hub and spoke projects.

## Input Variables
### Hub
| Variable Name | Description | Type | Default Value | Required |
|---------------|-------------|------|---------------|----------|
| prefix | Prefix for resource names to ensure uniqueness in the NCC hub project | string | "walid" | Yes |
| ncc_project_id | GCP project ID for the NCC hub project | string | None | Yes |
| ncc_region | GCP region for NCC hub resources (e.g., us-central1) | string | "us-central1" | Yes |
| ncc_subnet_cidr | CIDR range for the NCC hub subnet | string | "10.190.0.0/24" | Yes |
| ncc_asn | BGP ASN for the NCC hub Cloud Router | number | 64512 | Yes |
| ncc_credentials_path | Path to GCP credentials JSON file for NCC hub project | string | None | Yes |
| ncc_hub_service_account | Service account email for NCC hub project | string | None | Yes |
| ncc-hub_statefile_bucket_name | GCS bucket for hub Terraform state storage | string | None | Yes |
| gcs_bucket_name | GCS bucket for shared secrets | string | None | Yes |
| spoke_configs | List of spoke configurations | list(object) | [] | No |
| deploy_test_vm | Whether to deploy test VM in NCC hub | bool | true | No |
| test_vm_machine_type | Machine type for test VM | string | "e2-micro" | No |
| test_vm_image | Disk image for test VM | string | "debian-cloud/debian-11" | No |
| deploy_phase2 | Whether to deploy phase 2 resources (VPN tunnels, etc.) | bool | false | No |
| deploy_phase3 | Whether to deploy phase 3 outputs (all_spoke_cidrs) | bool | false | No |

### Spoke
| Variable Name | Description | Type | Default Value | Required |
|---------------|-------------|------|---------------|----------|
| prefix | Prefix for resource names | string | "walid" | Yes |
| spoke_project_id | GCP project ID for spoke project | string | None | Yes |
| spoke_region | GCP region for spoke resources | string | "us-central1" | Yes |
| spoke_subnet_cidr | CIDR range for spoke subnet | string | None | Yes |
| spoke_asn | BGP ASN for spoke Cloud Router | number | 64513 | Yes |
| spoke_credentials_path | Path to GCP credentials JSON file | string | None | Yes |
| spoke_statefile_bucket_name | GCS bucket for spoke state storage | string | None | Yes |
| spoke_name | Name identifier for the spoke | string | None | Yes |
| hub_service_account | Service account email for NCC hub project | string | None | Yes |
| deploy_test_vm | Whether to deploy test VM in spoke | bool | true | No |
| test_vm_machine_type | Machine type for test VM | string | "e2-micro" | No |
| test_vm_image | Disk image for test VM | string | "debian-cloud/debian-11" | No |
| gcs_bucket_name | GCS bucket for shared secrets | string | None | Yes |
| hub_state_bucket_name | GCS bucket for hub state storage | string | None | Yes |
| hub_prefix | Prefix for hub state in GCS | string | None | Yes |
| spoke_to_ncc_ip_range_0 | IP range for spoke-to-hub VPN tunnel 0 | string | None | Yes |
| spoke_to_ncc_ip_range_1 | IP range for spoke-to-hub VPN tunnel 1 | string | None | Yes |
| ncc_to_spoke_peer_ip_0 | Hub-side BGP peer IP for tunnel 0 | string | Yes |
| ncc_to_spoke_peer_ip_1 | Hub-side BGP peer IP for tunnel 1 | string | Yes |
| deploy_phase2 | Whether to deploy phase 2 resources | bool | false | No |
| deploy_phase3 | Whether to deploy phase 3 resources (spoke-to-spoke) | bool | false | No |

## Destruction Workflow

To safely delete the infrastructure:

1. **Phase 3 Destruction**: Set `deploy_phase3 = false` on all spokes
   ```bash
   cd spoke
   terraform apply -var="deploy_phase2=true" -var="deploy_phase3=false"
   
   cd ../spoke2
   terraform apply -var="deploy_phase2=true" -var="deploy_phase3=false"
   ```

2. **Phase 2 Destruction**: Set `deploy_phase2 = false` on hub and spokes **SIMULTANEOUSLY**
   ```bash
   # Hub and ALL spokes must run this at the same time
   cd hub
   terraform apply -var="deploy_phase2=false" -var="deploy_phase3=false"
   
   cd ../spoke
   terraform apply -var="deploy_phase2=false" -var="deploy_phase3=false"
   
   cd ../spoke2
   terraform apply -var="deploy_phase2=false" -var="deploy_phase3=false"
   ```

3. **Phase 1 Destruction**: Destroy all resources
   ```bash
   cd hub
   terraform destroy
   
   cd ../spoke
   terraform destroy
   
   cd ../spoke2
   terraform destroy
   ```

### **Important Destruction Notice**

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

## Contributing
Contributions are welcome! Please follow the existing conventions including lowercase naming, separate `variables.tf` and `outputs.tf`, and input validation.

## Changelog

# v2.0.0
- Added Phase 3 deployment for spoke-to-spoke communication
- Implemented dynamic firewall rules using `all_spoke_cidrs` output
- Improved dependency management and deployment sequencing
- Enhanced documentation and destruction workflow

# v1.0.0
- Initial release with two-phase deployment
- Basic hub-and-spoke connectivity
- GCS-based state management and shared secrets