# Deployment Guide

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Initial Setup](#initial-setup)
3. [Phase 1: Core Infrastructure](#phase-1-core-infrastructure)
4. [Phase 2: VPN Connectivity](#phase-2-vpn-connectivity)
5. [Phase 3: Spoke-to-Spoke Communication](#phase-3-spoke-to-spoke-communication)
6. [Optional: Task 2 - Cloud Run Deployment](#optional-task-2---cloud-run-deployment)
7. [Optional: Task 3 - Extended Infrastructure](#optional-task-3---extended-infrastructure)
8. [Verification Steps](#verification-steps)
9. [Troubleshooting](#troubleshooting)
10. [Destruction Workflow](#destruction-workflow)

---

## Prerequisites

### Required Tools

Before beginning deployment, ensure you have the following tools installed:

```bash
# Terraform (>= 1.0.0)
terraform version

# Google Cloud SDK
gcloud version

# Git (for cloning repositories)
git --version
```

### GCP Requirements

1. **GCP Projects**: You need at least 2 GCP projects (1 hub + 1+ spokes)
   - Hub project (e.g., `ncc-project-467401`)
   - Spoke project(s) (e.g., `pelagic-core-467122`, `spoke-b-467801`)

2. **Billing**: All projects must have billing enabled

3. **APIs**: Enable the following APIs in all projects:
   ```bash
   gcloud services enable compute.googleapis.com \
     networkconnectivity.googleapis.com \
     storage.googleapis.com \
     --project=<PROJECT_ID>
   ```

---

## Initial Setup

### Step 1: Create Service Accounts

#### Hub Service Account

```bash
# Set variables
export HUB_PROJECT_ID="ncc-project-467401"

# Create hub service account
gcloud iam service-accounts create hub-terraform-sa \
  --display-name="Hub Terraform Service Account" \
  --project=${HUB_PROJECT_ID}

# Grant necessary roles
gcloud projects add-iam-policy-binding ${HUB_PROJECT_ID} \
  --member="serviceAccount:hub-terraform-sa@${HUB_PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/compute.networkAdmin"

gcloud projects add-iam-policy-binding ${HUB_PROJECT_ID} \
  --member="serviceAccount:hub-terraform-sa@${HUB_PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/networkconnectivity.hubAdmin"

gcloud projects add-iam-policy-binding ${HUB_PROJECT_ID} \
  --member="serviceAccount:hub-terraform-sa@${HUB_PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/storage.admin"

# Create and download key
gcloud iam service-accounts keys create ~/G-secrets/hub-sa-key.json \
  --iam-account=hub-terraform-sa@${HUB_PROJECT_ID}.iam.gserviceaccount.com \
  --project=${HUB_PROJECT_ID}
```

#### Spoke Service Account(s)

```bash
# Set variables
export SPOKE_PROJECT_ID="pelagic-core-467122"
export SPOKE_NAME="spoke-a"

# Create spoke service account
gcloud iam service-accounts create ${SPOKE_NAME}-terraform-sa \
  --display-name="Spoke ${SPOKE_NAME} Terraform Service Account" \
  --project=${SPOKE_PROJECT_ID}

# Grant necessary roles in spoke project
gcloud projects add-iam-policy-binding ${SPOKE_PROJECT_ID} \
  --member="serviceAccount:${SPOKE_NAME}-terraform-sa@${SPOKE_PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/compute.networkAdmin"

gcloud projects add-iam-policy-binding ${SPOKE_PROJECT_ID} \
  --member="serviceAccount:${SPOKE_NAME}-terraform-sa@${SPOKE_PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/storage.admin"

# Grant hub service account access to spoke project
gcloud projects add-iam-policy-binding ${SPOKE_PROJECT_ID} \
  --member="serviceAccount:hub-terraform-sa@${HUB_PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/compute.networkUser"

# Grant spoke service account access to hub project
gcloud projects add-iam-policy-binding ${HUB_PROJECT_ID} \
  --member="serviceAccount:${SPOKE_NAME}-terraform-sa@${SPOKE_PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/compute.networkUser"

gcloud projects add-iam-policy-binding ${HUB_PROJECT_ID} \
  --member="serviceAccount:${SPOKE_NAME}-terraform-sa@${SPOKE_PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/networkconnectivity.spokeAdmin"

# Create and download key
gcloud iam service-accounts keys create ~/G-secrets/${SPOKE_NAME}-sa-key.json \
  --iam-account=${SPOKE_NAME}-terraform-sa@${SPOKE_PROJECT_ID}.iam.gserviceaccount.com \
  --project=${SPOKE_PROJECT_ID}
```

### Step 2: Create GCS Buckets

```bash
# Hub state bucket
gsutil mb -p ${HUB_PROJECT_ID} -l us-central1 gs://walid-hub-backend

# Enable versioning
gsutil versioning set on gs://walid-hub-backend

# Spoke state bucket
gsutil mb -p ${SPOKE_PROJECT_ID} -l us-central1 gs://walid-spoke-a-backend
gsutil versioning set on gs://walid-spoke-a-backend

# Shared secrets bucket (in hub project)
gsutil mb -p ${HUB_PROJECT_ID} -l us-central1 gs://walid-secrets-backend
gsutil versioning set on gs://walid-secrets-backend

# Grant IAM permissions for state access
gsutil iam ch \
  serviceAccount:${SPOKE_NAME}-terraform-sa@${SPOKE_PROJECT_ID}.iam.gserviceaccount.com:objectAdmin \
  gs://walid-hub-backend

gsutil iam ch \
  serviceAccount:hub-terraform-sa@${HUB_PROJECT_ID}.iam.gserviceaccount.com:objectAdmin \
  gs://walid-spoke-a-backend

gsutil iam ch \
  serviceAccount:${SPOKE_NAME}-terraform-sa@${SPOKE_PROJECT_ID}.iam.gserviceaccount.com:objectViewer \
  gs://walid-secrets-backend
```

### Step 3: Clone Repository

```bash
git clone https://github.com/Walid-Ahmed-Dev/Terraform-GCP-NCC-Hub-Spoke-Architecture_v2.git
cd Terraform-GCP-NCC-Hub-Spoke-Architecture_v2
```

### Step 4: Configure Terraform Variables

#### Hub Configuration (`hub/terraform.tfvars`)

```hcl
# Project and region
prefix         = "walid"
ncc_project_id = "ncc-project-467401"
ncc_region     = "us-central1"

# Network configuration
ncc_subnet_cidr = "10.190.0.0/24"
ncc_asn         = 64512

# Credentials
ncc_credentials_path          = "../../../G-secrets/hub-sa-key.json"
ncc_hub_service_account       = "hub-terraform-sa@ncc-project-467401.iam.gserviceaccount.com"
ncc-hub_statefile_bucket_name = "walid-hub-backend"
gcs_bucket_name               = "walid-secrets-backend"

# Spoke configurations
spoke_configs = [
  {
    name                        = "spoke-a"
    spoke_statefile_bucket_name = "walid-spoke-a-backend"
    spoke_state_prefix          = "spoke-a-state"
    service_account             = "spoke-a-terraform-sa@pelagic-core-467122.iam.gserviceaccount.com"
    ncc_to_spoke_ip_range_0     = "169.254.1.0/30"
    spoke_to_ncc_peer_ip_0      = "169.254.1.2"
    ncc_to_spoke_ip_range_1     = "169.254.2.0/30"
    spoke_to_ncc_peer_ip_1      = "169.254.2.2"
  }
]

# Deployment phases
deploy_phase2 = false
deploy_phase3 = false

# Optional test VM
deploy_test_vm       = true
test_vm_machine_type = "e2-micro"
test_vm_image        = "debian-cloud/debian-11"
```

#### Spoke Configuration (`spoke/terraform.tfvars`)

```hcl
# Project and region
prefix           = "walid"
spoke_project_id = "pelagic-core-467122"
spoke_region     = "us-central1"
spoke_name       = "spoke-a"

# Network configuration
spoke_subnet_cidr = "10.191.1.0/24"
spoke_asn         = 64513

# Credentials
spoke_credentials_path      = "../../../G-secrets/spoke-a-sa-key.json"
spoke_statefile_bucket_name = "walid-spoke-a-backend"

# Hub reference
hub_service_account   = "hub-terraform-sa@ncc-project-467401.iam.gserviceaccount.com"
hub_state_bucket_name = "walid-hub-backend"
hub_prefix            = "hub-state"
gcs_bucket_name       = "walid-secrets-backend"

# VPN configuration
spoke_to_ncc_ip_range_0 = "169.254.1.2/30"
ncc_to_spoke_peer_ip_0  = "169.254.1.1"
spoke_to_ncc_ip_range_1 = "169.254.2.2/30"
ncc_to_spoke_peer_ip_1  = "169.254.2.1"

# Deployment phases
deploy_phase2 = false
deploy_phase3 = false

# Optional test VM
deploy_test_vm       = true
test_vm_machine_type = "e2-micro"
test_vm_image        = "debian-cloud/debian-11"
```

---

## Phase 1: Core Infrastructure

Phase 1 establishes the foundational network resources without any VPN connectivity.

### Hub Phase 1 Deployment

```bash
cd hub

# Initialize Terraform
terraform init

# Review the plan
terraform plan \
  -var="deploy_phase2=false" \
  -var="deploy_phase3=false"

# Apply configuration
terraform apply \
  -var="deploy_phase2=false" \
  -var="deploy_phase3=false"

# Save outputs for spoke consumption
terraform output
```

**Expected Resources Created:**
- VPC Network (`walid-ncc-vpc`)
- Subnet (`walid-ncc-subnet` with CIDR `10.190.0.0/24`)
- HA VPN Gateway (2 interfaces)
- Cloud Router (ASN 64512)
- NCC Hub resource
- GCS bucket for shared secrets
- IAM role bindings
- Optional test VM

### Spoke Phase 1 Deployment

```bash
cd ../spoke

# Initialize Terraform
terraform init

# Review the plan
terraform plan \
  -var="deploy_phase2=false" \
  -var="deploy_phase3=false"

# Apply configuration
terraform apply \
  -var="deploy_phase2=false" \
  -var="deploy_phase3=false"

# Save outputs for hub consumption
terraform output
```

**Expected Resources Created:**
- VPC Network (`walid-spoke-spoke-a-vpc`)
- Subnet (`walid-spoke-spoke-a-subnet` with CIDR `10.191.1.0/24`)
- HA VPN Gateway (2 interfaces)
- Cloud Router (ASN 64513)
- IAM role bindings
- Optional test VM

### Verification

```bash
# Verify hub VPN gateway
gcloud compute vpn-gateways list --project=${HUB_PROJECT_ID}

# Verify spoke VPN gateway
gcloud compute vpn-gateways list --project=${SPOKE_PROJECT_ID}

# Check state files exist
gsutil ls gs://walid-hub-backend/hub-state/
gsutil ls gs://walid-spoke-a-backend/spoke-a-state/
```

---

## Phase 2: VPN Connectivity

Phase 2 establishes VPN tunnels and BGP peering between hub and spokes.

### Hub Phase 2 Deployment

```bash
cd hub

# Apply Phase 2 configuration
terraform apply \
  -var="deploy_phase2=true" \
  -var="deploy_phase3=false"
```

**Expected Resources Created:**
- VPN tunnels to each spoke (2 tunnels per spoke)
- BGP peers for each tunnel
- NCC spoke resources linking VPN tunnels to NCC hub
- Firewall rules for VPN traffic (ESP, IKE, NAT-T)
- Firewall rules for BGP traffic (TCP/179)
- Pre-shared secrets in GCS

### Spoke Phase 2 Deployment

```bash
cd ../spoke

# Apply Phase 2 configuration
terraform apply \
  -var="deploy_phase2=true" \
  -var="deploy_phase3=false"
```

**Expected Resources Created:**
- VPN tunnels to hub (2 tunnels)
- Cloud Router interfaces for each tunnel
- BGP peers for each tunnel
- Firewall rules for VPN and BGP traffic

### Verification

```bash
# Check VPN tunnel status (should be "Established")
gcloud compute vpn-tunnels list --project=${HUB_PROJECT_ID}
gcloud compute vpn-tunnels list --project=${SPOKE_PROJECT_ID}

# Check BGP sessions (should show "BGP_SESSION_UP")
gcloud compute routers get-status walid-ncc-cloud-router \
  --region=us-central1 \
  --project=${HUB_PROJECT_ID}

gcloud compute routers get-status walid-spoke-spoke-a-cloud-router \
  --region=us-central1 \
  --project=${SPOKE_PROJECT_ID}

# Test connectivity from spoke VM to hub VM
gcloud compute ssh walid-spoke-spoke-a-test-vm \
  --zone=us-central1-a \
  --project=${SPOKE_PROJECT_ID} \
  --tunnel-through-iap \
  --command="ping -c 4 10.190.0.2"
```

---

## Phase 3: Spoke-to-Spoke Communication

Phase 3 enables direct communication between spokes via dynamic firewall rules.

### Hub Phase 3 Deployment

```bash
cd hub

# Apply Phase 3 configuration
terraform apply \
  -var="deploy_phase2=true" \
  -var="deploy_phase3=true"

# Verify all_spoke_cidrs output
terraform output all_spoke_cidrs
# Expected output: ["10.191.1.0/24", "10.191.2.0/24"]
```

**Expected Resources Created:**
- `all_spoke_cidrs` output aggregating all spoke subnet CIDRs
- Firewall rules for spoke-to-spoke traffic in hub VPC

### Spoke Phase 3 Deployment

```bash
cd ../spoke

# Apply Phase 3 configuration
terraform apply \
  -var="deploy_phase2=true" \
  -var="deploy_phase3=true"
```

**Expected Resources Created:**
- Dynamic firewall rules allowing traffic from all other spoke CIDRs
- Firewall rules include both source and destination ranges for bidirectional communication

### Verification

```bash
# Test spoke-to-spoke connectivity (from spoke-a to spoke-b)
gcloud compute ssh walid-spoke-spoke-a-test-vm \
  --zone=us-central1-a \
  --project=${SPOKE_PROJECT_ID} \
  --tunnel-through-iap \
  --command="ping -c 4 10.191.2.2"
```

---

## Optional: Task 2 - Cloud Run Deployment

Task 2 deploys a Cloud Run service with multi-revision traffic splitting.

### Prerequisites

1. **Enable Cloud Run API**:
   ```bash
   gcloud services enable run.googleapis.com --project=${SPOKE_PROJECT_ID}
   gcloud services enable artifactregistry.googleapis.com --project=${SPOKE_PROJECT_ID}
   ```

2. **Create Artifact Registry**:
   ```bash
   gcloud artifacts repositories create cloud-run-ex \
     --repository-format=docker \
     --location=asia-northeast1 \
     --project=${SPOKE_PROJECT_ID}
   ```

3. **Build and Push Docker Images**:
   ```bash
   # Clone the reference application
   git clone https://github.com/Walid-Ahmed-Dev/cloud-run-ex.git
   cd cloud-run-ex

   # Build images
   docker build -t cloud-run-ex:latest .
   docker build -t cloud-run-ex2:latest .
   docker build -t cloud-run-ex3:latest .
   docker build -t cloud-run-ex4:latest .

   # Tag for Artifact Registry
   docker tag cloud-run-ex:latest asia-northeast1-docker.pkg.dev/${SPOKE_PROJECT_ID}/cloud-run-ex/cloud-run-ex:main
   docker tag cloud-run-ex2:latest asia-northeast1-docker.pkg.dev/${SPOKE_PROJECT_ID}/cloud-run-ex/cloud-run-ex2:revision2
   docker tag cloud-run-ex3:latest asia-northeast1-docker.pkg.dev/${SPOKE_PROJECT_ID}/cloud-run-ex/cloud-run-ex3:revision3
   docker tag cloud-run-ex4:latest asia-northeast1-docker.pkg.dev/${SPOKE_PROJECT_ID}/cloud-run-ex/cloud-run-ex4:revision4

   # Configure Docker authentication
   gcloud auth configure-docker asia-northeast1-docker.pkg.dev

   # Push images
   docker push asia-northeast1-docker.pkg.dev/${SPOKE_PROJECT_ID}/cloud-run-ex/cloud-run-ex:main
   docker push asia-northeast1-docker.pkg.dev/${SPOKE_PROJECT_ID}/cloud-run-ex/cloud-run-ex2:revision2
   docker push asia-northeast1-docker.pkg.dev/${SPOKE_PROJECT_ID}/cloud-run-ex/cloud-run-ex3:revision3
   docker push asia-northeast1-docker.pkg.dev/${SPOKE_PROJECT_ID}/cloud-run-ex/cloud-run-ex4:revision4
   ```

### Deployment

```bash
cd spoke3  # Or whichever spoke has Task 2 module

# Update terraform.tfvars to enable Task 2
cat >> terraform.tfvars <<EOF
deploy_task_2          = true
artifact_registry_host = "asia-northeast1-docker.pkg.dev"
repository_name        = "cloud-run-ex"
service_name           = "cloud-run-ex-service"
traffic_distribution = {
  main      = 40
  revision2 = 40
  revision3 = 10
  revision4 = 10
}
image_names = {
  main      = "cloud-run-ex"
  revision2 = "cloud-run-ex2"
  revision3 = "cloud-run-ex3"
  revision4 = "cloud-run-ex4"
}
EOF

# Deploy Task 2
terraform apply -var="deploy_task_2=true"

# Get service URL
terraform output task2_service_url
```

### Verification

```bash
# Test the Cloud Run service
SERVICE_URL=$(terraform output -raw task2_service_url)
curl ${SERVICE_URL}

# Check traffic splitting
gcloud run services describe cloud-run-ex-service \
  --region=asia-northeast1 \
  --project=${SPOKE_PROJECT_ID} \
  --format="get(status.traffic)"
```

---

## Optional: Task 3 - Extended Infrastructure

Task 3 deploys Windows jump boxes, Linux web servers, and an internal load balancer.

### Configuration

```bash
cd spoke  # Or whichever spoke has Task 3 module

# Update terraform.tfvars to enable Task 3
cat >> terraform.tfvars <<EOF
deploy_task_3           = true
windows_vm_region       = "asia-northeast1"
windows_vm_machine_type = "e2-standard-4"
linux_vm_machine_type   = "e2-medium"
task3_private_cidr      = "10.192.1.0/24"
group_member           = "walid"
EOF

# Deploy Task 3
terraform apply -var="deploy_task_3=true"
```

### Access Instructions

```bash
# Get Windows VM public IP and RDP command
terraform output task3_windows_vm_public_ip
terraform output task3_windows_vm_rdp_command

# Get Windows VM password
gcloud compute reset-windows-password walid-spoke-spoke-a-windows-vm \
  --zone=asia-northeast1-a \
  --project=${SPOKE_PROJECT_ID}

# Get internal load balancer IP
terraform output task3_internal_lb_ip_address
```

### Usage Workflow

1. **RDP to Windows VM**:
   ```bash
   # Use the RDP command from outputs
   # Username: (from reset-windows-password output)
   # Password: (from reset-windows-password output)
   ```

2. **Access Internal Load Balancer**:
   - From Windows VM, open a browser
   - Navigate to the internal load balancer IP
   - Each refresh will show a different Linux VM's personalized page

### Verification

```bash
# Check Windows VM status
gcloud compute instances describe walid-spoke-spoke-a-windows-vm \
  --zone=asia-northeast1-a \
  --project=${SPOKE_PROJECT_ID}

# Check instance group status
gcloud compute instance-groups managed list-instances \
  walid-spoke-spoke-a-mig \
  --region=us-central1 \
  --project=${SPOKE_PROJECT_ID}

# Check load balancer backend health
gcloud compute backend-services get-health \
  walid-spoke-spoke-a-backend-service \
  --region=us-central1 \
  --project=${SPOKE_PROJECT_ID}
```

---

## Verification Steps

### Network Connectivity Tests

```bash
# Test hub-to-spoke connectivity
gcloud compute ssh walid-ncc-test-vm \
  --zone=us-central1-a \
  --project=${HUB_PROJECT_ID} \
  --tunnel-through-iap \
  --command="ping -c 4 10.191.1.2"

# Test spoke-to-hub connectivity
gcloud compute ssh walid-spoke-spoke-a-test-vm \
  --zone=us-central1-a \
  --project=${SPOKE_PROJECT_ID} \
  --tunnel-through-iap \
  --command="ping -c 4 10.190.0.2"

# Test spoke-to-spoke connectivity (requires Phase 3)
gcloud compute ssh walid-spoke-spoke-a-test-vm \
  --zone=us-central1-a \
  --project=${SPOKE_PROJECT_ID} \
  --tunnel-through-iap \
  --command="ping -c 4 10.191.2.2"
```

### BGP Route Verification

```bash
# Check routes learned by hub router
gcloud compute routers get-status walid-ncc-cloud-router \
  --region=us-central1 \
  --project=${HUB_PROJECT_ID} \
  --format="table(result.bgpPeerStatus[].name,
                   result.bgpPeerStatus[].ipAddress,
                   result.bgpPeerStatus[].peerIpAddress,
                   result.bgpPeerStatus[].state,
                   result.bgpPeerStatus[].advertisedRoutes[].destRange,
                   result.bgpPeerStatus[].learnedRoutes[].destRange)"

# Check routes learned by spoke router
gcloud compute routers get-status walid-spoke-spoke-a-cloud-router \
  --region=us-central1 \
  --project=${SPOKE_PROJECT_ID} \
  --format="table(result.bgpPeerStatus[].name,
                   result.bgpPeerStatus[].ipAddress,
                   result.bgpPeerStatus[].peerIpAddress,
                   result.bgpPeerStatus[].state,
                   result.bgpPeerStatus[].advertisedRoutes[].destRange,
                   result.bgpPeerStatus[].learnedRoutes[].destRange)"
```

### NCC Hub Status

```bash
# Check NCC hub status
gcloud network-connectivity hubs describe walid-ncc-hub \
  --project=${HUB_PROJECT_ID}

# List NCC spokes
gcloud network-connectivity spokes list \
  --hub=walid-ncc-hub \
  --project=${HUB_PROJECT_ID}
```

---

## Troubleshooting

### VPN Tunnels Not Establishing

**Symptom**: VPN tunnel status shows "FIRST_HANDSHAKE" or "WAITING_FOR_FULL_CONFIG"

**Solution**:
```bash
# Verify pre-shared secrets match
gsutil cat gs://walid-secrets-backend/shared-secrets/spoke-a-shared-secret.txt

# Check firewall rules allow VPN traffic
gcloud compute firewall-rules list \
  --filter="name~vpn" \
  --project=${HUB_PROJECT_ID}

# Verify VPN gateway interfaces
gcloud compute vpn-gateways describe walid-ncc-vpn-gateway \
  --region=us-central1 \
  --project=${HUB_PROJECT_ID}
```

### BGP Sessions Down

**Symptom**: BGP peer status shows "DOWN" or no routes learned

**Solution**:
```bash
# Verify router ASN configuration
gcloud compute routers describe walid-ncc-cloud-router \
  --region=us-central1 \
  --project=${HUB_PROJECT_ID}

# Check BGP peer IP addresses match
terraform output -state=hub/terraform.tfstate
terraform output -state=spoke/terraform.tfstate

# Verify firewall allows BGP (TCP/179)
gcloud compute firewall-rules describe walid-ncc-allow-vpn-bgp \
  --project=${HUB_PROJECT_ID}
```

### Spoke-to-Spoke Communication Fails

**Symptom**: Cannot ping between spokes despite Phase 3 deployment

**Solution**:
```bash
# Verify hub Phase 3 outputs exist
cd hub
terraform output all_spoke_cidrs

# Check spoke firewall rules include all spoke CIDRs
gcloud compute firewall-rules describe walid-spoke-spoke-a-allow-spoke-to-spoke \
  --project=${SPOKE_PROJECT_ID}

# Verify routes learned via BGP include other spoke subnets
gcloud compute routers get-status walid-spoke-spoke-a-cloud-router \
  --region=us-central1 \
  --project=${SPOKE_PROJECT_ID}
```

### Terraform State Lock Issues

**Symptom**: "Error locking state" or "Another Terraform process is running"

**Solution**:
```bash
# Force unlock (use with caution)
terraform force-unlock <LOCK_ID>

# Verify state bucket accessibility
gsutil ls gs://walid-hub-backend/hub-state/

# Check IAM permissions on state bucket
gsutil iam get gs://walid-hub-backend
```

### Task 2 Deployment Fails

**Symptom**: Cloud Run revision deployment or traffic splitting fails

**Solution**:
```bash
# Verify images exist in Artifact Registry
gcloud artifacts docker images list \
  asia-northeast1-docker.pkg.dev/${SPOKE_PROJECT_ID}/cloud-run-ex

# Check Cloud Run service status
gcloud run services describe cloud-run-ex-service \
  --region=asia-northeast1 \
  --project=${SPOKE_PROJECT_ID}

# Verify gcloud authentication
gcloud auth list
```

### Task 3 Windows VM RDP Fails

**Symptom**: Cannot connect to Windows VM via RDP

**Solution**:
```bash
# Verify Windows VM has external IP
gcloud compute instances describe walid-spoke-spoke-a-windows-vm \
  --zone=asia-northeast1-a \
  --project=${SPOKE_PROJECT_ID} \
  --format="get(networkInterfaces[0].accessConfigs[0].natIP)"

# Check RDP firewall rule
gcloud compute firewall-rules describe walid-spoke-spoke-a-allow-rdp \
  --project=${SPOKE_PROJECT_ID}

# Reset Windows password
gcloud compute reset-windows-password walid-spoke-spoke-a-windows-vm \
  --zone=asia-northeast1-a \
  --project=${SPOKE_PROJECT_ID}
```

---

## Destruction Workflow

To safely tear down the infrastructure, follow the reverse deployment order:

### Step 1: Destroy Task 2 (if deployed)

```bash
cd spoke3
terraform apply -var="deploy_task_2=false"
```

### Step 2: Destroy Task 3 (if deployed)

```bash
cd spoke
terraform apply -var="deploy_task_3=false"
```

### Step 3: Destroy Phase 3 (Spoke-to-Spoke)

```bash
# Disable Phase 3 on all spokes
cd spoke
terraform apply -var="deploy_phase2=true" -var="deploy_phase3=false"

cd ../spoke2
terraform apply -var="deploy_phase2=true" -var="deploy_phase3=false"

# Disable Phase 3 on hub
cd ../hub
terraform apply -var="deploy_phase2=true" -var="deploy_phase3=false"
```

### Step 4: Destroy Phase 2 (VPN Connectivity)

**IMPORTANT**: Hub and ALL spokes must disable Phase 2 simultaneously to avoid state dependency errors.

```bash
# Disable Phase 2 on hub
cd hub
terraform apply -var="deploy_phase2=false" -var="deploy_phase3=false"

# Disable Phase 2 on all spokes (run concurrently)
cd ../spoke
terraform apply -var="deploy_phase2=false" -var="deploy_phase3=false" &

cd ../spoke2
terraform apply -var="deploy_phase2=false" -var="deploy_phase3=false" &

wait
```

### Step 5: Destroy Phase 1 (Core Infrastructure)

```bash
# Destroy spokes first
cd spoke
terraform destroy

cd ../spoke2
terraform destroy

# Destroy hub last
cd ../hub
terraform destroy
```

### Step 6: Clean Up GCS Buckets (Optional)

```bash
# Delete state buckets
gsutil -m rm -r gs://walid-hub-backend
gsutil -m rm -r gs://walid-spoke-a-backend
gsutil -m rm -r gs://walid-secrets-backend
```

### Step 7: Remove Service Accounts (Optional)

```bash
# Delete hub service account
gcloud iam service-accounts delete \
  hub-terraform-sa@${HUB_PROJECT_ID}.iam.gserviceaccount.com \
  --project=${HUB_PROJECT_ID}

# Delete spoke service account
gcloud iam service-accounts delete \
  spoke-a-terraform-sa@${SPOKE_PROJECT_ID}.iam.gserviceaccount.com \
  --project=${SPOKE_PROJECT_ID}
```

---

## Best Practices

### Security

1. **Rotate Service Account Keys** every 90 days
2. **Store credentials outside version control** (use `.gitignore`)
3. **Use least privilege IAM roles** for service accounts
4. **Enable VPC Flow Logs** for network troubleshooting
5. **Enable Cloud Audit Logs** for compliance

### Operational

1. **Always deploy phases in order**: Phase 1 → Phase 2 → Phase 3
2. **Verify outputs** before proceeding to the next phase
3. **Test connectivity** after each phase deployment
4. **Use Terraform workspaces** for multiple environments
5. **Document custom configurations** in comments

### Cost Optimization

1. **Use `e2-micro` instances** for test VMs (covered by free tier)
2. **Scale Cloud Run to zero** when idle (automatic)
3. **Delete unused VPN tunnels** to avoid hourly charges
4. **Use preemptible VMs** for non-production workloads
5. **Set up billing alerts** to monitor costs

---

## Additional Resources

- [GCP Network Connectivity Center Documentation](https://cloud.google.com/network-connectivity/docs/network-connectivity-center)
- [Terraform Google Provider Documentation](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [GCP VPN Gateway Documentation](https://cloud.google.com/network-connectivity/docs/vpn)
- [BGP Routing with Cloud Router](https://cloud.google.com/network-connectivity/docs/router)
- [Original Repository (v1)](https://github.com/Walid-Ahmed-Dev/Terraform-GCP-NCC-Hub-Spoke-Architecture)

---

## Support

For issues or questions:
1. Check the [Troubleshooting](#troubleshooting) section
2. Review Terraform logs: `terraform apply 2>&1 | tee terraform.log`
3. Open an issue on GitHub
4. Consult GCP documentation for specific resource errors
