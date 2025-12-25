# Terraform Outputs
# =================
# Export important resource information for use in other systems

output "gcp_project_id" {
  description = "GCP Project ID"
  value       = var.gcp_project_id
}

output "raw_zone_bucket" {
  description = "Raw zone GCS bucket name"
  value       = google_storage_bucket.raw_zone.name
}

output "processed_zone_bucket" {
  description = "Processed zone GCS bucket name"
  value       = google_storage_bucket.processed_zone.name
}

output "service_account_email" {
  description = "ELT Pipeline service account email"
  value       = google_service_account.elt_pipeline.email
}

output "service_account_key" {
  description = "ELT Pipeline service account key (private key JSON) - SAVE THIS SECURELY!"
  value       = base64decode(google_service_account_key.elt_pipeline_key.private_key)
  sensitive   = true
}

output "bigquery_datasets" {
  description = "BigQuery datasets created"
  value = {
    bronze   = google_bigquery_dataset.bronze.dataset_id
    silver   = google_bigquery_dataset.silver.dataset_id
    gold     = google_bigquery_dataset.gold.dataset_id
    dev      = google_bigquery_dataset.dev.dataset_id
  }
}

output "terraform_state_bucket" {
  description = "Recommended bucket name for Terraform state storage"
  value       = "${var.gcp_project_id}-terraform-state"
}

output "setup_instructions" {
  description = "Next steps to complete setup"
  value = <<-EOT
    
    ✅ GCP Infrastructure provisioned successfully!
    
    📋 Next Steps:
    
    1. Save the service account key securely:
       - Copy the service_account_key output
       - Save to: credentials/service-account.json
       - Never commit this file!
    
    2. Configure credentials:
       - Set environment variable: export GOOGLE_APPLICATION_CREDENTIALS="path/to/service-account.json"
       - Or add to GitHub Secrets: GCP_SERVICE_ACCOUNT_KEY
    
    3. Update dbt profiles:
       - Edit profiles.yml with your GCP project ID
       - Run: dbt debug
    
    4. Test connectivity:
       - Run: python scripts/data_acquisition.py --test
       - Run: gsutil ls (should list your buckets)
    
    5. Create remote Terraform state (recommended):
       - Create GCS bucket: ${var.gcp_project_id}-terraform-state
       - Uncomment backend block in main.tf
       - Run: terraform init
    
    📊 Resources Created:
    - GCS Buckets: ${google_storage_bucket.raw_zone.name}, ${google_storage_bucket.processed_zone.name}
    - BigQuery Datasets: olist_bronze, olist_silver, olist_gold, olist_dev
    - Service Account: ${google_service_account.elt_pipeline.email}
    
    🔐 Security Reminders:
    - Never commit service account keys to git
    - Use GitHub Secrets for CI/CD authentication
    - Regularly rotate service account keys
    - Monitor GCP billing alerts
    
  EOT
}
