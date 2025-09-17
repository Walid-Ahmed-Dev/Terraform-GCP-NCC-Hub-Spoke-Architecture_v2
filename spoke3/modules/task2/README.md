# Task 2 Module - Cloud Run Multi-Revision Deployment

This module implements a sophisticated Cloud Run deployment strategy using a hybrid Terraform + gcloud CLI approach for precise traffic splitting across multiple revisions.

## 🏗️ Architectural Design & Rationale

### Why This Hybrid Approach?

This solution uses a **Terraform + gcloud CLI hybrid architecture** to overcome Terraform's limitations in managing multiple Cloud Run revisions within a single service.

#### 🎯 **The Core Problem: Terraform Limitations**
- **Terraform cannot natively manage multiple Cloud Run revisions** within a single service
- **Random revision suffixes** (`-00001-fc6`, `-00002-x7y`) make automation unpredictable
- **No built-in traffic splitting** across multiple existing revisions

#### 🚀 **The Solution: Strategic Hybrid Approach**

```hcl
# 1. Terraform manages the service infrastructure
resource "google_cloud_run_service" "main" {
  name     = var.service_name
  location = var.region
  # ... configuration
  lifecycle {
    ignore_changes = all  # Intentional divergence
  }
}

# 2. gcloud CLI handles revision deployment (predictable naming)
resource "null_resource" "deploy_revisions" {
  provisioner "local-exec" {
    command = <<EOT
      gcloud run deploy ${var.service_name} \
        --revision-suffix=main \          # ← Predictable naming!
        --no-traffic
      # ... other revisions
    EOT
  }
}

# 3. gcloud CLI handles traffic splitting
resource "null_resource" "split_traffic" {
  provisioner "local-exec" {
    command = <<EOT
      gcloud run services update-traffic ${var.service_name} \
        --to-revisions=service-main=40,service-revision2=40,...  # ← Predictable!
    EOT
  }
}
```

### 📊 Architecture Diagram

```
Terraform Control Plane
│
├── Service Infrastructure (state managed)
│   └── Cloud Run Service
│
└── Local-Exec Provisioners
    ├── Revision Deployment (gcloud)
    │   └── Creates: service-main, service-revision2, etc.
    │
    └── Traffic Splitting (gcloud)
        └── Routes traffic: 40%/40%/10%/10%
```

## 📋 Prerequisites

Before using this module, you must:

1. **Enable required APIs** in your GCP project:
   ```bash
   gcloud services enable run.googleapis.com
   gcloud services enable artifactregistry.googleapis.com
   ```

2. **Create an Artifact Registry repository**:
   ```bash
   gcloud artifacts repositories create ${var.repository_name} \
     --repository-format=docker \
     --location=${var.spoke_region} \
     --description="Cloud Run example repository"
   ```

3. **Build and push Docker images** to your Artifact Registry:

```bash
# Clone the reference application
git clone https://github.com/Walid-Ahmed-Dev/cloud-run-ex.git
cd cloud-run-ex

# Build Docker images for each revision
sudo docker build -t cloud-run-ex:latest .
sudo docker build -t cloud-run-ex2:latest .
sudo docker build -t cloud-run-ex3:latest . 
sudo docker build -t cloud-run-ex4:latest .

# Tag images for your Artifact Registry
docker tag cloud-run-ex ${var.artifact_registry_host}/${var.project_id}/${var.repository_name}/cloud-run-ex:main
docker tag cloud-run-ex2 ${var.artifact_registry_host}/${var.project_id}/${var.repository_name}/cloud-run-ex2:revision2
docker tag cloud-run-ex3 ${var.artifact_registry_host}/${var.project_id}/${var.repository_name}/cloud-run-ex3:revision3
docker tag cloud-run-ex4 ${var.artifact_registry_host}/${var.project_id}/${var.repository_name}/cloud-run-ex4:revision4

# Push to Artifact Registry
docker push ${var.artifact_registry_host}/${var.project_id}/${var.repository_name}/cloud-run-ex:main
docker push ${var.artifact_registry_host}/${var.project_id}/${var.repository_name}/cloud-run-ex2:revision2
docker push ${var.artifact_registry_host}/${var.project_id}/${var.repository_name}/cloud-run-ex3:revision3
docker push ${var.artifact_registry_host}/${var.project_id}/${var.repository_name}/cloud-run-ex4:revision4
```

## 🚀 Usage

```hcl
module "task2" {
  source           = "./modules/task2"
  spoke_region     = var.spoke_region
  spoke_project_id = var.spoke_project_id

  artifact_registry_host = var.artifact_registry_host
  repository_name        = var.repository_name
  service_name           = var.service_name
  traffic_distribution   = var.traffic_distribution
  image_names            = var.image_names

  deploy_task_2 = var.deploy_task_2
}
```

## 📊 Input Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| spoke_project_id | The GCP spoke project ID | string | n/a | yes |
| spoke_region | The GCP spoke region | string | n/a | yes |
| artifact_registry_host | Artifact Registry hostname | string | `"asia-docker.pkg.dev"` | no |
| repository_name | Artifact Registry repository name | string | `"cloud-run-ex"` | no |
| service_name | Cloud Run service name | string | `"cloud-run-ex-service"` | no |
| traffic_distribution | Traffic distribution across revisions | map(number) | `{ main = 40, revision2 = 40, revision3 = 10, revision4 = 10 }` | no |
| image_names | Docker image names for each revision | map(string) | `{ main = "cloud-run-ex", revision2 = "cloud-run-ex2", revision3 = "cloud-run-ex3", revision4 = "cloud-run-ex4" }` | no |
| deploy_task_2 | Whether to deploy Task 2 resources | bool | `false` | no |


## 🏢 Resources Created

This module creates the following resources when `deploy_task_2 = true`:

### Cloud Run Resources
- **Cloud Run Service**: The main service infrastructure
- **IAM Member**: Public access configuration for the service

### Local Execution Resources
- **Revision Deployment**: Uses `null_resource` with `local-exec` to deploy revisions with predictable names
- **Traffic Splitting**: Uses `null_resource` with `local-exec` to configure traffic distribution

## 🤔 Addressing Common Questions

### ❓ "Why is there an extra revision from Terraform?"

**Answer**: The Terraform-created revision (`service-00001-fc6`) serves as:

1. **State anchor**: Ensures Terraform maintains ownership of the service infrastructure
2. **Initial deployment**: Provides a baseline before gcloud takes over revision management
3. **Safety net**: Guarantees the service exists before CLI operations begin

### ❓ "Is this wasteful?"

**Answer**: **No, and here's why:**

- **💰 Zero Cost Impact**: Cloud Run only charges for **active requests**
- **📉 Auto-scaling**: Unused revisions scale to **zero instances**
- **🗑️ Automatic Cleanup**: Google automatically garbage collects old revisions after 30 days
- **⚡ Minimal Resources**: Idle revisions consume no CPU/memory

### ❓ "Can I delete the Terraform-created revision?"

**Answer**: **Yes, but you shouldn't need to:**

- **It's harmless**: Sits idle with zero traffic
- **Self-cleaning**: GCP automatically removes it after 30 days
- **No benefit**: Deleting it manually provides no cost or performance improvement

## 🎯 Benefits of This Architecture

### ✅ **Predictable Naming**
```bash
# Before (random, unpredictable)
cloud-run-ex-service-00001-fc6
cloud-run-ex-service-00002-x7y

# After (consistent, predictable)  
cloud-run-ex-service-main
cloud-run-ex-service-revision2
```

### ✅ **State Management + Flexibility**
- **Terraform**: Manages service infrastructure, IAM, settings
- **gcloud**: Handles revision deployment and traffic control
- **Best of both**: Infrastructure as code + operational flexibility

### ✅ **Cost Optimized**
- **Pay-per-use**: Only active revisions consume resources
- **Zero waste**: Idle revisions cost nothing
- **Auto-cleanup**: No manual revision management needed

## ⚖️ Tradeoffs Accepted

This architecture intentionally accepts:

1. **Minor state drift**: The `ignore_changes = all` allows gcloud operations
2. **Extra idle revision**: One unused revision for state management
3. **CLI dependency**: Requires gcloud for revision operations

In exchange for:

1. **Predictable automation**: Consistent revision names
2. **Complete traffic control**: Precise percentage-based routing  
3. **Full state management**: Terraform-controlled infrastructure
4. **Zero cost impact**: Idle resources are free

## 🔧 When to Use This Pattern

- ✅ **Blue-green deployments** with traffic splitting
- ✅ **Canary releases** with percentage-based rollout  
- ✅ **A/B testing** multiple service versions
- ✅ **Any scenario requiring predictable revision names**

## 🗑️ Destruction

To remove Task 2 resources, set `deploy_task_2 = false`:

```bash
cd spoke
terraform apply -var="deploy_task_2=false"
```

This architecture represents a **practical compromise** between Terraform's state management and Cloud Run's operational realities.