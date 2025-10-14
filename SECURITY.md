# Security Considerations

## Credential Management Strategy

### Design Philosophy

This project uses **relative paths to credentials stored outside the project directory** (e.g., `../../../G-secrets/`). This is an **intentional design decision** for the following reasons:

1. **Simplicity in Development Workflow**: Enables rapid prototyping and local development without complex credential management setup
2. **Clear Separation**: Physically separates secrets from code, making it obvious what should never be committed
3. **Quick Deployment**: Allows developers to "hit the ground running" and stand up infrastructure quickly

### Security Pattern Explained

```
Project Structure:
├── Documents/
│   ├── G-secrets/              # ← Credentials directory (OUTSIDE project)
│   │   ├── hub-sa-key.json
│   │   ├── spoke-a-sa-key.json
│   │   └── spoke-b-sa-key.json
│   └── terraform/
│       └── GCP/
│           └── Terraform-GCP-NCC-Hub-Spoke-Architecture_v2/  # ← Project root
│               ├── .gitignore   # ← Protects credentials
│               ├── hub/
│               │   └── main.tf  # ← References ../../../G-secrets/
│               └── spoke/
```

**Why This Works:**
- Credentials are stored **3 directories up** from the project root
- Even if `.gitignore` fails, credentials are physically outside the Git repository
- Path references like `../../../G-secrets/` are relative and won't expose your actual filesystem structure

### Example from Code

```hcl
# hub/main.tf (lines 14-18)
backend "gcs" {
  bucket      = "walid-hub-backend"
  prefix      = "hub-state"
  credentials = "../../../G-secrets/ncc-project-467401-b10d53e43df4.json"  # ← Outside project
}
```

This approach prioritizes **developer experience** while maintaining reasonable security for personal/development projects.

---

## ⚠️ Important: If You Fork This Project

### You MUST Do These Things:

#### 1. Store Credentials Outside Your Project
```bash
# Create a credentials directory OUTSIDE your project
mkdir -p ~/G-secrets  # Or any location outside your repo

# Move or create your service account keys there
mv your-sa-key.json ~/G-secrets/

# Update your terraform.tfvars or backend config
credentials = "../../../G-secrets/your-sa-key.json"
```

#### 2. Add Credentials Path to .gitignore

The `.gitignore` file in this project already includes:
```gitignore
# Credentials and secrets
**/*credentials*.json
**/*-key.json
**/service-account*.json

# Credentials directory (customize to your path)
**/G-secrets/**
../../../G-secrets/**
```

**Verify it works:**
```bash
# Check that Git ignores your credentials
git status

# Your credentials should NOT appear in untracked files
# If they do, add their path to .gitignore immediately
```

#### 3. Never Commit Credentials

```bash
# Before your first commit, verify:
git add .
git status  # Check for any .json files in the list

# If you accidentally staged credentials:
git reset HEAD path/to/credentials.json
```

---

## Production-Grade Alternatives

For **production environments**, consider these more robust approaches:

### Option 1: Workload Identity Federation (Recommended)

```hcl
# No credentials needed in code!
provider "google" {
  project = var.project_id
  region  = var.region
  # Credentials automatically obtained from Workload Identity
}

terraform {
  backend "gcs" {
    bucket = "my-terraform-state"
    prefix = "terraform/state"
    # No credentials field - uses Application Default Credentials
  }
}
```

**Setup:**
```bash
# Configure Workload Identity for your CI/CD pipeline
gcloud iam workload-identity-pools create terraform-pool \
  --location="global" \
  --project="my-project"

# For local development, use ADC
gcloud auth application-default login
```

### Option 2: Environment Variables

```hcl
provider "google" {
  project     = var.project_id
  region      = var.region
  credentials = file(var.credentials_path)  # Path from environment variable
}
```

**Usage:**
```bash
# Set environment variable
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/credentials.json"
export TF_VAR_credentials_path="/path/to/credentials.json"

# Run Terraform
terraform apply
```

### Option 3: Secret Management Services

**Using Google Secret Manager:**
```bash
# Store credential in Secret Manager
gcloud secrets create terraform-sa-key \
  --data-file=service-account-key.json

# Access in Terraform via data source
data "google_secret_manager_secret_version" "sa_key" {
  secret = "terraform-sa-key"
}
```

**Using HashiCorp Vault:**
```hcl
data "vault_generic_secret" "gcp_creds" {
  path = "secret/gcp/terraform-sa"
}

provider "google" {
  credentials = data.vault_generic_secret.gcp_creds.data["key"]
}
```

---

## Security Checklist

Before deploying to production or sharing your fork:

- [ ] Credentials stored **outside** project directory
- [ ] `.gitignore` configured to exclude credentials
- [ ] Run `git status` to verify no credentials are staged
- [ ] Consider using Workload Identity or environment variables
- [ ] Enable VPC Service Controls for production projects
- [ ] Use separate service accounts per environment (dev/staging/prod)
- [ ] Rotate service account keys every 90 days
- [ ] Enable audit logging for all GCP projects
- [ ] Review IAM permissions follow least-privilege principle
- [ ] Enable MFA on all GCP accounts
- [ ] Use separate GCP organizations for production vs. development

---

## CI/CD Considerations

When setting up CI/CD pipelines (GitHub Actions, GitLab CI, etc.):

### Option 1: Workload Identity Federation (Best Practice)

```yaml
# .github/workflows/terraform.yml
jobs:
  terraform:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write  # Required for Workload Identity
    steps:
      - uses: actions/checkout@v3

      - id: auth
        uses: google-github-actions/auth@v1
        with:
          workload_identity_provider: 'projects/123/locations/global/...'
          service_account: 'terraform@my-project.iam.gserviceaccount.com'

      - name: Terraform Apply
        run: terraform apply -auto-approve
```

### Option 2: Encrypted Secrets (Acceptable)

```yaml
# .github/workflows/terraform.yml
jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup credentials
        run: |
          echo "${{ secrets.GCP_SA_KEY }}" | base64 -d > /tmp/gcp-key.json
          export GOOGLE_APPLICATION_CREDENTIALS=/tmp/gcp-key.json

      - name: Terraform Apply
        run: terraform apply -auto-approve
        env:
          GOOGLE_APPLICATION_CREDENTIALS: /tmp/gcp-key.json
```

---

## What NOT to Do

### ❌ Hardcoding Credentials in Code

```hcl
# NEVER DO THIS
provider "google" {
  credentials = <<EOF
{
  "type": "service_account",
  "project_id": "my-project",
  "private_key": "-----BEGIN PRIVATE KEY-----\n..."
}
EOF
}
```

### ❌ Committing Credentials to Git

```bash
# If you accidentally committed credentials:

# 1. Remove from Git history (use BFG Repo-Cleaner or git filter-branch)
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch path/to/credentials.json" \
  --prune-empty --tag-name-filter cat -- --all

# 2. Force push to remote
git push origin --force --all

# 3. IMMEDIATELY rotate the compromised credentials
gcloud iam service-accounts keys delete KEY_ID \
  --iam-account=SA_EMAIL

# 4. Create new credentials
gcloud iam service-accounts keys create new-key.json \
  --iam-account=SA_EMAIL
```

### ❌ Storing Credentials in Terraform State

```hcl
# AVOID storing credentials in resources that go into state
resource "google_service_account_key" "terraform" {
  service_account_id = google_service_account.terraform.name
  # This creates a key and stores it in state file - risky!
}
```

---

## Questions?

If you're unsure about credential management:

1. **For Personal Projects**: The approach in this repo (external directory) is fine
2. **For Production**: Use Workload Identity Federation
3. **For CI/CD**: Use encrypted secrets or Workload Identity
4. **For Teams**: Use a secrets management service (Vault, Secret Manager)

**When in doubt**: If you can see a credential in plain text anywhere in your repo, it's wrong.

---

## Additional Resources

- [GCP Best Practices for Service Account Keys](https://cloud.google.com/iam/docs/best-practices-for-managing-service-account-keys)
- [Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation)
- [Terraform Backend Configuration](https://www.terraform.io/language/settings/backends/gcs)
- [Git Secrets Tool](https://github.com/awslabs/git-secrets) - Prevent committing credentials
- [TruffleHog](https://github.com/trufflesecurity/truffleHog) - Scan for secrets in Git history
