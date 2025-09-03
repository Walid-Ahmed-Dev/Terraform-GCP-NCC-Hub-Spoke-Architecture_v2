output "ncc_subnet_cidr" {
  value = module.ncc_hub.ncc_subnet_cidr
}

output "ncc_asn" {
  value = module.ncc_hub.ncc_asn
}

output "ncc_vpn_gateway_id" {
  value = module.ncc_hub.ncc_vpn_gateway_id
}

output "ncc_test_vm_name" {
  value = module.ncc_hub.ncc_test_vm_name
}

output "ncc_test_vm_internal_ip" {
  value = module.ncc_hub.ncc_test_vm_internal_ip
}

output "ncc_test_vm_self_link" {
  value = module.ncc_hub.ncc_test_vm_self_link
}

output "spoke_vpn_tunnels" {
  value = module.ncc_hub.spoke_vpn_tunnels
}

output "all_spoke_cidrs" { 
  value = module.ncc_hub.all_spoke_cidrs
}