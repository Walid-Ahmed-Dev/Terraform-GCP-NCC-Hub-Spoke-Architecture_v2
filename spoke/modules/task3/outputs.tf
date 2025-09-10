output "windows_vm_public_ip" {
  description = "Public IP address of the Windows VM for RDP access"
  value       = var.deploy_task_3 ? google_compute_instance.task3_windows_vm[0].network_interface[0].access_config[0].nat_ip : null
}

output "internal_lb_ip_address" {
  description = "Internal IP address of the load balancer (copy-paste into browser)"
  value       = var.deploy_task_3 ? google_compute_address.task3_internal_lb_ip[0].address : null
}

output "internal_lb_url" {
  description = "Full URL to access the internal load balancer"
  value       = var.deploy_task_3 ? "http://${google_compute_address.task3_internal_lb_ip[0].address}" : null
}

output "windows_vm_rdp_command" {
  description = "RDP command to connect to the Windows VM"
  value       = var.deploy_task_3 ? "mstsc /v:${google_compute_instance.task3_windows_vm[0].network_interface[0].access_config[0].nat_ip}" : null
}