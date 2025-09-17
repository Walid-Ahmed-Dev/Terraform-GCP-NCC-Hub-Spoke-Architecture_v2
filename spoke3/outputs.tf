output "spoke_vpc_id" {
  value = module.ncc_spoke.spoke_vpc_id
}

output "spoke_subnet_id" {
  value = module.ncc_spoke.spoke_subnet_id

}

output "spoke_subnet_cidr" {
  description = "CIDR range of the spoke subnet"
  value       = module.ncc_spoke.spoke_subnet_cidr
}

output "spoke_asn" {
  value = module.ncc_spoke.spoke_asn
}

output "spoke_vpn_gateway_id" {
  value = module.ncc_spoke.spoke_vpn_gateway_id
}

output "spoke_test_vm_name" {
  value = module.ncc_spoke.spoke_test_vm_name
}

output "spoke_test_vm_internal_ip" {
  value = module.ncc_spoke.spoke_test_vm_internal_ip
}


output "spoke_test_vm_self_link" {
  value = module.ncc_spoke.spoke_test_vm_self_link
}

output "spoke_vpn_tunnel_ids" {
  value = module.ncc_spoke.spoke_vpn_tunnel_ids
}

####################################
######### Task 2 OUTPUTS ###########
####################################

output "service_url" {
  value = module.task2.service_url
}

####################################
######### Task 3 OUTPUTS ###########
####################################

output "windows_vm_public_ip" {
  value = module.task3.windows_vm_public_ip
}

output "internal_lb_ip_address" {
  value = module.task3.internal_lb_ip_address
}

output "internal_lb_url" {
  value = module.task3.internal_lb_url
}

output "windows_vm_rdp_command" {
  value = module.task3.windows_vm_rdp_command
}
