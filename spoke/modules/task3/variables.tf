
variable "prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "spoke_project_id" {
  description = "The GCP spoke project ID"
  type        = string
}

variable "spoke_region" {
  description = "The GCP spoke region"
  type        = string
}

variable "spoke_name" {
  description = "Name of the spoke"
  type        = string
}

variable "spoke_vpc_id" {
  description = "ID of the existing spoke VPC"
  type        = string
}

variable "spoke_subnet_id" {
  description = "ID of the existing spoke subnet"
  type        = string
}


variable "windows_vm_region" {
  description = "Region for the Windows VM"
  type        = string
}

variable "windows_vm_machine_type" {
  description = "Machine type for Windows VM"
  type        = string
}

variable "linux_vm_machine_type" {
  description = "Machine type for Linux VMs"
  type        = string
  default     = "e2-medium"
}

variable "task3_private_cidr" {
  description = "CIDR for Task 3 private subnet"
  type        = string
  default     = "10.192.1.0/24"
}

variable "group_member" {
  description = "Group member"
  type        = string
}

variable "deploy_task_3" {
  description = "Whether to deploy Task 3 resources"
  type        = bool
  default     = false
}