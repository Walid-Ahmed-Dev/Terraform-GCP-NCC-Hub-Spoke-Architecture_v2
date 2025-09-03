prefix                      = "walid1"
spoke_project_id            = "pelagic-core-467122-q4"
spoke_region                = "asia-northeast1"
spoke_credentials_path      = "../../../G-secrets/pelagic-core-467122-q4-25d0b2aa49f2.json"
spoke_subnet_cidr           = "10.191.1.0/24"
spoke_asn                   = 65001
spoke_name                  = "spoke-a"
spoke_statefile_bucket_name = "walid-spoke-a-backend"
gcs_bucket_name             = "walid-secrets-backend"

hub_state_bucket_name   = "walid-hub-backend"
hub_prefix              = "hub-state"
hub_service_account     = "admin-428@ncc-project-467401.iam.gserviceaccount.com"
spoke_to_ncc_ip_range_0 = "169.254.0.2/30"
ncc_to_spoke_peer_ip_0  = "169.254.0.1"
spoke_to_ncc_ip_range_1 = "169.254.1.2/30"
ncc_to_spoke_peer_ip_1  = "169.254.1.1"

deploy_test_vm       = true
test_vm_machine_type = "e2-micro"
test_vm_image        = "debian-cloud/debian-11"


deploy_phase2 = false
deploy_phase3 = false