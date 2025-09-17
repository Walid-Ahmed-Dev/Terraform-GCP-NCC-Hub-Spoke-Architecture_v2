prefix                      = "walid3"
spoke_project_id            = "kong089"
spoke_region                = "asia-northeast3"
spoke_credentials_path      = "../../../G-secrets/kong089-3dfa0248dc8e.json"
spoke_subnet_cidr           = "10.191.3.0/24"
spoke_asn                   = 65003
spoke_name                  = "spoke-c"
spoke_statefile_bucket_name = "walid-spoke-c-backend"
gcs_bucket_name             = "walid-secrets-backend"

hub_state_bucket_name   = "walid-hub-backend"
hub_prefix              = "hub-state"
hub_service_account     = "admin-428@ncc-project-467401.iam.gserviceaccount.com"
spoke_to_ncc_ip_range_0 = "169.254.4.2/30"
ncc_to_spoke_peer_ip_0  = "169.254.4.1"
spoke_to_ncc_ip_range_1 = "169.254.5.2/30"
ncc_to_spoke_peer_ip_1  = "169.254.5.1"

deploy_test_vm       = true
test_vm_machine_type = "e2-micro"
test_vm_image        = "debian-cloud/debian-11"


deploy_phase2 = false
deploy_phase3 = false

#############################
####### TASK 2 CONFIG #######
#############################
# Task 2 deployment control
deploy_task_2 = false

# Artifact Registry Configuration  
artifact_registry_host = "asia-docker.pkg.dev"
repository_name        = "cloud-run-ex"
service_name           = "cloud-run-ex-service"

# Image Names (must match your built/pushed images)
image_names = {
  main      = "cloud-run-ex"
  revision2 = "cloud-run-ex2"
  revision3 = "cloud-run-ex3"
  revision4 = "cloud-run-ex4"
}

# Traffic Distribution (percentages must sum to 100)
traffic_distribution = {
  main      = 40
  revision2 = 40
  revision3 = 10
  revision4 = 10
}

#############################
####### TASK 3 CONFIG #######
#############################

# Task 3 deployment control
deploy_task_3 = false

# Task 3 specific configuration
windows_vm_region       = "asia-northeast3"
windows_vm_machine_type = "e2-standard-4"
linux_vm_machine_type   = "e2-medium"
task3_private_cidr      = "10.192.3.0/24"

# Group member for Task 3
group_member = "walid"