prefix                      = "walid2"
spoke_project_id            = "aws-ultramarines-466800"
spoke_region                = "europe-central2"
spoke_credentials_path      = "../../../G-secrets/aws-ultramarines-466800-77ac1c30a414.json"
spoke_subnet_cidr           = "10.191.2.0/24"
spoke_asn                   = 65002
spoke_name                  = "spoke-b"
spoke_statefile_bucket_name = "walid-spoke-b-backend"
gcs_bucket_name             = "walid-secrets-backend"

hub_state_bucket_name   = "walid-hub-backend"
hub_prefix              = "hub-state"
hub_service_account     = "admin-428@ncc-project-467401.iam.gserviceaccount.com"
spoke_to_ncc_ip_range_0 = "169.254.2.2/30"
ncc_to_spoke_peer_ip_0  = "169.254.2.1"
spoke_to_ncc_ip_range_1 = "169.254.3.2/30"
ncc_to_spoke_peer_ip_1  = "169.254.3.1"

deploy_test_vm       = true
test_vm_machine_type = "e2-micro"
test_vm_image        = "debian-cloud/debian-11"


deploy_phase2 = false
deploy_phase3 = false