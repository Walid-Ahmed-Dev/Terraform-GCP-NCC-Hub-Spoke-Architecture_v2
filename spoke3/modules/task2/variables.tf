variable "spoke_project_id" {
  description = "The GCP spoke project ID"
  type        = string
}

variable "spoke_region" {
  description = "The GCP spoke region"
  type        = string
}

variable "artifact_registry_host" {
  description = "Artifact Registry hostname"
  type        = string
  default     = "asia-docker.pkg.dev"
}

variable "repository_name" {
  description = "Artifact Registry repository name"
  type        = string
  default     = "cloud-run-ex"
}

variable "service_name" {
  description = "Cloud Run service name"
  type        = string
  default     = "cloud-run-ex-service"
}

variable "traffic_distribution" {
  description = "Traffic distribution across revisions"
  type        = map(number)
  default = {
    main      = 40
    revision2 = 40
    revision3 = 10
    revision4 = 10
  }
}

variable "image_names" {
  description = "Docker image names for each revision"
  type        = map(string)
  default = {
    main      = "cloud-run-ex"
    revision2 = "cloud-run-ex2"
    revision3 = "cloud-run-ex3"
    revision4 = "cloud-run-ex4"
  }
}

variable "deploy_task_2" {
  description = "Whether to deploy Task 3 resources"
  type        = bool
  default     = false
}