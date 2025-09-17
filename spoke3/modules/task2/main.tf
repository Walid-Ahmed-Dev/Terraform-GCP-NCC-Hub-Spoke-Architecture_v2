terraform {
  required_version = ">= 1.0.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~>3.0"
    }
  }
}
# Deploy the first revision and gain state management
resource "google_cloud_run_service" "main" {
  count    = var.deploy_task_2 ? 1 : 0
  name     = var.service_name
  location = var.spoke_region

  template {
    spec {
      containers {
        image = "${var.artifact_registry_host}/${var.spoke_project_id}/${var.repository_name}/${var.image_names["main"]}:main"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  lifecycle {
    # State management without the drift prevention i.e., state management with intentional divergence.  
    ignore_changes = all
  }
}

# Public access
resource "google_cloud_run_service_iam_member" "public_access" {
  count    = var.deploy_task_2 ? 1 : 0
  service  = google_cloud_run_service.main[count.index].name
  location = google_cloud_run_service.main[count.index].location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Deploy other revisions
resource "null_resource" "deploy_revisions" {
  count      = var.deploy_task_2 ? 1 : 0
  depends_on = [google_cloud_run_service.main]

  provisioner "local-exec" {
    command = <<EOT
      %{for revision, image in var.image_names~}
      gcloud run deploy ${var.service_name} \
        --image=${var.artifact_registry_host}/${var.spoke_project_id}/${var.repository_name}/${image}:${revision} \
        --region=${var.spoke_region} \
        --revision-suffix=${revision} \
        --no-traffic
      %{endfor~}
    EOT
  }
}

# Split traffic 
resource "null_resource" "split_traffic" {
  count      = var.deploy_task_2 ? 1 : 0
  depends_on = [null_resource.deploy_revisions]

  provisioner "local-exec" {
    command = <<EOT
      gcloud run services update-traffic ${var.service_name} \
        --region=${var.spoke_region} \
        --to-revisions=\
${var.service_name}-main=40,\
${var.service_name}-revision2=40,\
${var.service_name}-revision3=10,\
${var.service_name}-revision4=10
    EOT
  }
}