# Task 3 Module - Extended Spoke Functionality

This module extends the basic NCC spoke architecture with additional functionality including Windows jump boxes, Linux web servers, internal load balancing, and enhanced security features.

## Overview

The Task 3 module extends the existing NCC spoke infrastructure by:
- Creating a public-facing subnet in a different region for Windows jump box
- Deploying a Windows VM with RDP access for administrative purposes
- Setting up Linux web servers with personalized content for each group member
- Implementing an internal load balancer for high availability
- Adding private NAT for Linux servers to access package updates
- Configuring tag-based firewall rules for secure communication

## Usage

```hcl
module "task3" {
  source = "./modules/task3"
  
  # Shared variables with NCC spoke module
  prefix           = var.prefix
  spoke_project_id = var.spoke_project_id
  spoke_region     = var.spoke_region
  spoke_name       = var.spoke_name
  
  # VPC and subnet information from NCC spoke module
  spoke_vpc_id    = module.ncc_spoke.spoke_vpc_id
  spoke_subnet_id = module.ncc_spoke.spoke_subnet_id
  
  # Task 3 specific configuration
  task3_private_cidr      = var.task3_private_cidr
  windows_vm_region       = var.windows_vm_region
  windows_vm_machine_type = var.windows_vm_machine_type
  linux_vm_machine_type   = var.linux_vm_machine_type
  group_member           = var.group_member
  
  # Deployment control
  deploy_task_3 = var.deploy_task_3
  
  providers = {
    google = google
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| prefix | Prefix for resource names | string | n/a | yes |
| spoke_project_id | The GCP spoke project ID | string | n/a | yes |
| spoke_region | The GCP spoke region | string | n/a | yes |
| spoke_name | Name of the spoke | string | n/a | yes |
| spoke_vpc_id | ID of the existing spoke VPC | string | n/a | yes |
| spoke_subnet_id | ID of the existing spoke subnet | string | n/a | yes |
| windows_vm_region | Region for the Windows VM | string | n/a | yes |
| windows_vm_machine_type | Machine type for Windows VM | string | n/a | yes |
| linux_vm_machine_type | Machine type for Linux VMs | string | `"e2-medium"` | no |
| task3_private_cidr | CIDR for Task 3 private subnet | string | `"10.192.3.0/24"` | no |
| group_member | Group member for Linux VM customization | string | n/a | yes |
| deploy_task_3 | Whether to deploy Task 3 resources | bool | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| windows_vm_public_ip | Public IP address of the Windows VM for RDP access |
| internal_lb_ip_address | Internal IP address of the load balancer |
| internal_lb_url | Full URL to access the internal load balancer |
| windows_vm_rdp_command | RDP command to connect to the Windows VM |

## Resources Created

This module creates the following resources when `deploy_task_3 = true`:

### Networking
- **Public Subnet**: New subnet for Windows VM in specified region
- **Router**: Cloud Router for private NAT
- **NAT**: Private NAT for Linux VMs internet access
- **NAT IP**: External IP address for NAT

### Security
- **Firewall Rule**: RDP access to Windows VM from internet (0.0.0.0/0)
- **Firewall Rule**: Windows to Linux communication on port 80

### Compute
- **Windows VM**: Public-facing Windows jump box with RDP access
- **Linux Instance Template**: Template for Linux web servers
- **Managed Instance Group**: Auto-scaling group for Linux VMs across two zones

### Load Balancing
- **Internal IP Address**: Static IP for internal load balancer
- **Forwarding Rule**: Internal load balancer configuration
- **Backend Service**: Load balancer backend service
- **Health Check**: Regional health check for Linux VMs

## Features

### Windows Jump Box
- Publicly accessible via RDP
- Located in separate region from private infrastructure
- Serves as administrative access point

### Linux Web Servers
- Deployed in existing private subnet
- Personalized content for each group member
- Multi-zone deployment for high availability
- Automated health checks and instance replacement

### Internal Load Balancer
- Distributes traffic across Linux web servers
- Regional health monitoring
- Single internal IP address for access

### Security Features
- Tag-based firewall rules instead of IP-based
- Private NAT for secure outbound internet access
- Restricted communication between Windows and Linux VMs

## Dependencies

- Existing NCC spoke VPC and subnet
- Internet access for Windows VM (public IP)
- Appropriate IAM permissions for resource creation

## Deployment Notes

1. Ensure `deploy_task_3 = true` to enable this module
2. Windows VM region can be different from spoke region
3. Linux VMs use existing private subnet infrastructure
4. Firewall rules use tags for access control
5. Private NAT allows Linux VMs to access internet for updates

## Access Instructions

After deployment:
1. Use the `windows_vm_rdp_command` output to connect to Windows VM
2. From Windows VM, access the internal load balancer using `internal_lb_ip_address`
3. The load balancer will distribute requests across member-specific Linux VMs

## Customization

The module supports customization through:
- Machine type selection for both Windows and Linux VMs
- CIDR range for public subnet
- Group member name for personalized content
- Regional placement of Windows VM

## Destruction

Set `deploy_task_3 = false` to remove all Task 3 resources while preserving the core NCC spoke infrastructure.