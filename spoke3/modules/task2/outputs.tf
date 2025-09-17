output "service_url" {
  value = var.deploy_task_2 ? google_cloud_run_service.main[0].status[0].url : null
}