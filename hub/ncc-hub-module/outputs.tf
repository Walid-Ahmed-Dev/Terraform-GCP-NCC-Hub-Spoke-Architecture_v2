# Required for Spoke
output "ncc_subnet_cidr" {
  value       = google_compute_subnetwork.ncc_subnet.ip_cidr_range
  description = "CIDR range of the hub subnet"
}

# Required for Spoke
output "ncc_asn" {
  value       = google_compute_router.ncc_cloud_router.bgp[0].asn
  description = "BGP ASN of the hub Cloud Router"
}

# Required for spoke
output "ncc_vpn_gateway_id" {
  value       = google_compute_ha_vpn_gateway.ncc_vpn_gateway.id
  description = "ID of the hub HA VPN Gateway for spoke peer_gcp_gateway references"
}

# For testing
output "ncc_test_vm_name" {
  value       = var.deploy_test_vm ? google_compute_instance.ncc_test_vm[0].name : null
  description = "Name of the test VM deployed in the hub (if deployed)"
}

# For testing
output "ncc_test_vm_internal_ip" {
  description = "Internal IP address of the NCC Hub test VM"
  value       = var.deploy_test_vm ? google_compute_instance.ncc_test_vm[0].network_interface[0].network_ip : null
}

# For testing
output "ncc_test_vm_self_link" {
  value       = var.deploy_test_vm ? google_compute_instance.ncc_test_vm[0].self_link : null
  description = "Self link of the test VM deployed in the hub (if deployed)"
}

#############################
######### Phase 2 ##########
#############################

# Outputs the VPN tunnel IDs for each spoke for validation
output "spoke_vpn_tunnels" {
  value = var.deploy_phase2 ? {
    for spoke_name in keys(google_compute_vpn_tunnel.ncc_to_spoke_0) : spoke_name => {
      tunnel_0_id = google_compute_vpn_tunnel.ncc_to_spoke_0[spoke_name].id
      tunnel_1_id = google_compute_vpn_tunnel.ncc_to_spoke_1[spoke_name].id
    }
  } : {}
  description = "Map of spoke names to their respective VPN tunnel IDs (tunnel 0 and tunnel 1), used by spokes to verify connectivity and by the hub to configure NCC spokes (google_network_connectivity_spoke.linked_vpn_tunnels.uris)."
}
output "all_spoke_cidrs" {
  description = "List of all spoke subnet CIDRs for phase 3 spoke-to-spoke communication"
  value = var.deploy_phase3 ? [
    for spoke in var.spoke_configs : 
    data.terraform_remote_state.spoke[spoke.name].outputs.spoke_subnet_cidr
  ] : []
}