prefix                        = "walid1"
ncc_project_id                = "ncc-project-467401"
ncc_region                    = "us-central1"
ncc_subnet_cidr               = "10.190.0.0/24"
ncc_asn                       = 64512
ncc_credentials_path          = "../../../G-secrets/ncc-project-467401-210df7f1e23a.json"
ncc_hub_service_account       = "admin-428@ncc-project-467401.iam.gserviceaccount.com"
ncc-hub_statefile_bucket_name = "walid-gcs-backend"
gcs_bucket_name               = "walid-gcs-backend3"
spoke_configs = [
  {
    name                        = "spoke-a"
    spoke_statefile_bucket_name = "walid-gcs-backend2"
    spoke_state_prefix          = "spoke-a-state"
    service_account             = "admin-532@pelagic-core-467122-q4.iam.gserviceaccount.com"
    ncc_to_spoke_ip_range_0     = "169.254.0.1/30"
    spoke_to_ncc_peer_ip_0      = "169.254.0.2"
    ncc_to_spoke_ip_range_1     = "169.254.1.1/30"
    spoke_to_ncc_peer_ip_1      = "169.254.1.2"
  }
]
deploy_test_vm       = true
test_vm_machine_type = "e2-micro"
test_vm_image        = "debian-cloud/debian-11"

deploy_phase2 = true

