# Required for Hub
output "spoke_subnet_cidr" {
  value       = var.spoke_subnet_cidr
  description = "CIDR range of the spoke subnet"
}

# Required for Hub
output "spoke_asn" {
  value       = var.spoke_asn
  description = "BGP ASN of the spoke Cloud Router"
}

# Required for Hub
output "spoke_vpn_gateway_id" {
  value       = google_compute_ha_vpn_gateway.spoke_vpn_gateway.id
  description = "ID of the spoke HA VPN Gateway for hub peer_gcp_gateway references"
}

# For testing
output "spoke_test_vm_name" {
  value       = var.deploy_test_vm ? google_compute_instance.spoke_test_vm[0].name : null
  description = "Name of the test VM deployed in the spoke (if deployed)"
}

# For testing
output "spoke_test_vm_internal_ip" {
  description = "Internal IP address of the NCC Hub test VM"
  value       = var.deploy_test_vm ? google_compute_instance.spoke_test_vm[0].network_interface[0].network_ip : null
}

# For testing
output "spoke_test_vm_self_link" {
  value       = var.deploy_test_vm ? google_compute_instance.spoke_test_vm[0].self_link : null
  description = "Self link of the test VM deployed in the spoke (if deployed)"
}

#############################
######### Phase 2 ##########
#############################

# Outputs the VPN tunnel IDs for validation (Phase 2)
output "spoke_vpn_tunnel_ids" {
  value = var.deploy_phase2 ? {
    tunnel_0 = google_compute_vpn_tunnel.spoke_to_ncc_0[0].id
    tunnel_1 = google_compute_vpn_tunnel.spoke_to_ncc_1[0].id
  } : {}
  description = "IDs of the VPN tunnels from spoke to NCC hub, used for validation and debugging."
}