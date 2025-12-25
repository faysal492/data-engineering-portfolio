# Terraform Infrastructure as Code - GCP Setup

This directory contains Terraform code to provision GCP infrastructure for the Brazilian E-Commerce ELT pipeline.

## Architecture

The Terraform configuration creates:

```
GCP Project
├── Cloud Storage (Raw Zone)
│   └── gs://project-raw-zone/olist/[table]/[date]/
├── Cloud Storage (Processed Zone)
│   └── gs://project-processed-zone/
├── BigQuery
│   ├── olist_bronze (raw layer)
│   ├── olist_silver (cleaned layer)
│   ├── olist_gold (analytics layer)
│   └── olist_dev (development)
├── Service Account (elt-pipeline)
│   └── Roles: BigQuery User, BigQuery Editor, Storage Admin
└── Budget Alerts
    └── Monthly $1 alert threshold
```

## Prerequisites

1. **GCP Account** with billing enabled
2. **GCP Project** already created (Terraform won't create it)
3. **Terraform** installed (>= 1.0)
4. **Google Cloud SDK** (`gcloud` CLI)
5. **Authentication**: Logged in locally with sufficient permissions

## Setup Instructions

### Step 1: Authenticate with GCP

```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
```

### Step 2: Prepare Terraform Variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values:
```hcl
gcp_project_id       = "your-actual-project-id"
gcp_region           = "us-central1"
bq_location          = "US"
enable_billing_alert = true
monthly_budget_usd   = 1.0
billing_account_id   = "01A2B3-C4D5E6-F7G8H9"
```

### Step 3: Initialize Terraform

```bash
terraform init
```

This downloads required providers and prepares the working directory.

### Step 4: Plan the Infrastructure

```bash
terraform plan -out=tfplan
```

Review the output to ensure it matches your expectations.

### Step 5: Apply the Configuration

```bash
terraform apply tfplan
```

This creates all GCP resources. Wait for completion (~5-10 minutes).

### Step 6: Save Service Account Key

The service account key is automatically created. Extract and save it:

```bash
# Get the key (base64 encoded in Terraform state)
terraform output -raw service_account_key > credentials/service-account.json

# Verify it's valid JSON
cat credentials/service-account.json | jq .

# Set permissions (important!)
chmod 600 credentials/service-account.json
```

### Step 7: Configure Environment

```bash
# Set the credentials environment variable
export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/credentials/service-account.json"

# Verify connectivity
gcloud auth activate-service-account --key-file=credentials/service-account.json
gcloud config set project YOUR_PROJECT_ID
gsutil ls  # Should list your buckets
```

### Step 8: Update dbt Configuration

Edit `profiles.yml` with your project ID:

```yaml
brazilian_ecommerce:
  target: dev
  outputs:
    dev:
      project: "YOUR_PROJECT_ID"
      dataset: olist_dev
      keyfile: "path/to/credentials/service-account.json"
```

Test dbt connection:

```bash
dbt debug
```

## File Structure

```
terraform/
├── main.tf                 # Main configuration (GCS, BigQuery, IAM)
├── variables.tf            # Input variable definitions
├── outputs.tf              # Output values
├── terraform.tfvars.example # Example variables (copy and fill)
├── README.md               # This file
└── .terraform/             # Terraform working directory (gitignored)
```

## Important Files to NOT Commit

Add to `.gitignore` (already included):

```
terraform/.terraform/
terraform/*.tfstate
terraform/*.tfstate.*
terraform/*.tfplan
terraform/.terraform.lock.hcl
terraform/terraform.tfvars
credentials/service-account.json
```

## Common Tasks

### View Current Infrastructure

```bash
terraform show
```

### View Outputs

```bash
terraform output
terraform output service_account_email
terraform output -raw service_account_key > key.json
```

### Update Infrastructure

Edit `main.tf` or `variables.tf`, then:

```bash
terraform plan -out=tfplan
terraform apply tfplan
```

### Destroy Infrastructure (⚠️ Dangerous)

```bash
# This deletes ALL resources!
terraform destroy
```

### Migrate to Remote State

After initial setup, store Terraform state in GCS:

```bash
# Create state bucket
gsutil mb -p YOUR_PROJECT_ID gs://YOUR_PROJECT_ID-terraform-state

# Update main.tf backend block
# Uncomment and modify:
# backend "gcs" {
#   bucket = "YOUR_PROJECT_ID-terraform-state"
#   prefix = "modern-elt-warehouse"
# }

# Migrate state
terraform init
# Answer "yes" when asked to migrate existing state
```

## Cost Considerations

This configuration is designed to stay within GCP Free Tier:

- **Cloud Storage**: 5 GB/month free
- **BigQuery**: 1 TB/month queries free, 1 GB/month storage free
- **Service Accounts**: Free
- **Budget Alerts**: Free monitoring

## Troubleshooting

### Error: "Project not found"

```
Error: Error reading Project "projects/YOUR_ID": googleapi: Error 403
```

**Solution**: Create the GCP project first or update `gcp_project_id`.

### Error: "Permission denied"

```
Error: Error creating Service Account: googleapi: Error 403: Permission 'iam.serviceAccounts.create' denied
```

**Solution**: Ensure you have Owner or Editor role on the GCP project.

### Error: "Billing account not found"

```
Error: Error creating Budget: googleapi: Error 400: Billing account ... not found
```

**Solution**: 
- Get your billing account: `gcloud billing accounts list`
- Update `billing_account_id` in `terraform.tfvars`
- Or set `enable_billing_alert = false` if not available

### Service account key is empty

The key is stored securely in Terraform state. Extract it:

```bash
terraform output -raw service_account_key > credentials/service-account.json
cat credentials/service-account.json | jq .  # Verify it's valid
```

## Security Best Practices

1. **Never commit sensitive files**:
   - `terraform.tfvars` (contains billing account ID)
   - Service account keys
   - `terraform.tfstate` (contains encoded secrets)

2. **Rotate service account keys regularly**:
   ```bash
   gcloud iam service-accounts keys create new-key.json \
     --iam-account=elt-pipeline@PROJECT_ID.iam.gserviceaccount.com
   ```

3. **Use GitHub Secrets for CI/CD**:
   - Store `GOOGLE_APPLICATION_CREDENTIALS` base64-encoded in GitHub Secrets
   - Decode in GitHub Actions before use

4. **Enable Cloud Audit Logs**:
   ```bash
   gcloud logging sinks create bigquery-sink \
     bigquery.googleapis.com/projects/PROJECT_ID/datasets/audit_logs \
     --log-filter='resource.type="service_account"'
   ```

## Next Steps

After Terraform setup completes:

1. ✅ Run `TASK-004`: Download data from Kaggle
2. ✅ Run `TASK-006`: Upload to GCS with partitioning
3. ✅ Run `TASK-008`: Initialize dbt project
4. ✅ Run `TASK-009+`: Build transformation models

## Useful Commands

```bash
# Format terraform code
terraform fmt -recursive

# Validate syntax
terraform validate

# List all resources
terraform state list

# Remove resource from state (dangerous!)
terraform state rm 'resource_type.resource_name'

# Import existing resource
terraform import 'resource_type.resource_name' 'resource_id'
```

## Support

For issues:
1. Check GCP Console for resource creation status
2. Review Terraform logs: `terraform show`
3. Check Cloud Audit Logs in GCP Console
4. Run: `gcloud logging read --limit 50`

## References

- [Terraform Google Provider Docs](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Google Cloud Best Practices](https://cloud.google.com/docs/terraform/best-practices)
- [BigQuery Terraform Resources](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/bigquery_dataset)
