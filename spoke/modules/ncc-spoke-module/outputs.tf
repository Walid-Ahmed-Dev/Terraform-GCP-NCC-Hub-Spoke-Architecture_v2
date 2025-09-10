# Required for Hub
output "spoke_vpc_id" {
  description = "VPC of the spoke"
  value       = google_compute_network.spoke_vpc.id
}
output "spoke_subnet_cidr" {
  description = "CIDR range of the spoke subnet"
  value       = google_compute_subnetwork.spoke_subnet.ip_cidr_range
}

output "spoke_subnet_id" {
  description = "Spoke subnet ID"
  value       = google_compute_subnetwork.spoke_subnet.id
}

# Required for Hub
output "spoke_asn" {
  description = "BGP ASN of the spoke Cloud Router"
  value       = var.spoke_asn
}

# Required for Hub
output "spoke_vpn_gateway_id" {
  description = "ID of the spoke HA VPN Gateway for hub peer_gcp_gateway references"
  value       = google_compute_ha_vpn_gateway.spoke_vpn_gateway.id
}

# For testing
output "spoke_test_vm_name" {
  description = "Name of the test VM deployed in the spoke (if deployed)"
  value       = var.deploy_test_vm ? google_compute_instance.spoke_test_vm[0].name : null
}

# For testing
output "spoke_test_vm_internal_ip" {
  description = "Internal IP address of the NCC Hub test VM"
  value       = var.deploy_test_vm ? google_compute_instance.spoke_test_vm[0].network_interface[0].network_ip : null
}

# For testing
output "spoke_test_vm_self_link" {
  description = "Self link of the test VM deployed in the spoke (if deployed)"
  value       = var.deploy_test_vm ? google_compute_instance.spoke_test_vm[0].self_link : null
}

#############################
######### Phase 2 ##########
#############################

# Outputs the VPN tunnel IDs for validation (Phase 2)
output "spoke_vpn_tunnel_ids" {
  description = "IDs of the VPN tunnels from spoke to NCC hub, used for validation and debugging."
  value = var.deploy_phase2 ? {
    tunnel_0 = google_compute_vpn_tunnel.spoke_to_ncc_0[0].id
    tunnel_1 = google_compute_vpn_tunnel.spoke_to_ncc_1[0].id
  } : {}
}