output "spoke_subnet_cidr" {
  value = module.ncc_spoke.spoke_subnet_cidr
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