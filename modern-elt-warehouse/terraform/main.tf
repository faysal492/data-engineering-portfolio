# Main Terraform Configuration for GCP Infrastructure
# =====================================================
# This file provisions the following GCP resources for the Brazilian E-Commerce ELT pipeline:
# 1. GCP Project (already exists - you provide the ID)
# 2. Cloud Storage buckets (raw-zone and processed-zone)
# 3. BigQuery datasets (bronze, silver, gold layers)
# 4. Service account with minimal required permissions
# 5. IAM roles for the service account
# 6. Budget alerts for cost control

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
  }

  # Uncomment this block after first apply to use remote state
  # backend "gcs" {
  #   bucket = "your-terraform-state-bucket"
  #   prefix = "modern-elt-warehouse"
  # }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

provider "google-beta" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

# Get current GCP project information
data "google_client_config" "current" {}

# Get billing account information
data "google_billing_account" "account" {
  display_name = "My Billing Account"
  open         = true
}

# ============================================================================
# 1. ENABLE REQUIRED GCP APIs
# ============================================================================

resource "google_project_service" "bigquery" {
  service            = "bigquery.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "storage" {
  service            = "storage-api.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "iam" {
  service            = "iam.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "resourcemanager" {
  service            = "cloudresourcemanager.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "monitoring" {
  service            = "monitoring.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "billing_budgets" {
  service            = "billingbudgets.googleapis.com"
  disable_on_destroy = false
}

# ============================================================================
# 2. CLOUD STORAGE BUCKETS
# ============================================================================

# Raw Zone Bucket - stores downloaded data from Kaggle
resource "google_storage_bucket" "raw_zone" {
  name          = "${var.gcp_project_id}-raw-zone"
  location      = var.gcp_region
  force_destroy = false

  uniform_bucket_level_access = true

  versioning {
    enabled = false
  }

  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type          = "SetStorageClass"
      storage_class = "STANDARD"
    }
  }

  lifecycle_rule {
    condition {
      age = 365
    }
    action {
      type          = "Delete"
    }
  }

  labels = {
    environment = "production"
    layer       = "raw"
    project     = "olist-ecommerce"
  }

  depends_on = [google_project_service.storage]
}

# Processed Zone Bucket - stores transformed data
resource "google_storage_bucket" "processed_zone" {
  name          = "${var.gcp_project_id}-processed-zone"
  location      = var.gcp_region
  force_destroy = false

  uniform_bucket_level_access = true

  versioning {
    enabled = false
  }

  lifecycle_rule {
    condition {
      age = 180
    }
    action {
      type          = "Delete"
    }
  }

  labels = {
    environment = "production"
    layer       = "processed"
    project     = "olist-ecommerce"
  }

  depends_on = [google_project_service.storage]
}

# ============================================================================
# 3. BIGQUERY DATASETS
# ============================================================================

# Bronze Layer - raw data from GCS
resource "google_bigquery_dataset" "bronze" {
  dataset_id    = "olist_bronze"
  friendly_name = "Bronze Layer"
  description   = "Raw data loaded from GCS (Kaggle Olist dataset)"
  location      = var.bq_location

  labels = {
    layer       = "bronze"
    environment = "production"
  }

  depends_on = [google_project_service.bigquery]
}

# Silver Layer - cleaned and validated data
resource "google_bigquery_dataset" "silver" {
  dataset_id    = "olist_silver"
  friendly_name = "Silver Layer"
  description   = "Cleaned and validated data with business logic applied"
  location      = var.bq_location

  labels = {
    layer       = "silver"
    environment = "production"
  }

  depends_on = [google_project_service.bigquery]
}

# Gold Layer - analytics-ready data (star schema)
resource "google_bigquery_dataset" "gold" {
  dataset_id    = "olist_gold"
  friendly_name = "Gold Layer"
  description   = "Analytics-ready fact and dimension tables (star schema)"
  location      = var.bq_location

  labels = {
    layer       = "gold"
    environment = "production"
  }

  depends_on = [google_project_service.bigquery]
}

# Development dataset for testing
resource "google_bigquery_dataset" "dev" {
  dataset_id    = "olist_dev"
  friendly_name = "Development"
  description   = "Development and testing dataset for dbt"
  location      = var.bq_location

  labels = {
    layer       = "dev"
    environment = "development"
  }

  depends_on = [google_project_service.bigquery]
}

# ============================================================================
# 4. SERVICE ACCOUNT FOR ELT PIPELINE
# ============================================================================

resource "google_service_account" "elt_pipeline" {
  account_id   = "elt-pipeline"
  display_name = "ELT Pipeline Service Account"
  description  = "Service account for Brazilian E-Commerce ELT pipeline"

  depends_on = [google_project_service.iam]
}

# ============================================================================
# 5. IAM ROLES & PERMISSIONS
# ============================================================================

# BigQuery User - run queries
resource "google_project_iam_member" "bigquery_user" {
  project = var.gcp_project_id
  role    = "roles/bigquery.user"
  member  = "serviceAccount:${google_service_account.elt_pipeline.email}"

  depends_on = [google_project_service.iam]
}

# BigQuery Data Editor - modify datasets and tables
resource "google_project_iam_member" "bigquery_editor" {
  project = var.gcp_project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.elt_pipeline.email}"

  depends_on = [google_project_service.iam]
}

# BigQuery Job User - create and run jobs
resource "google_project_iam_member" "bigquery_job_user" {
  project = var.gcp_project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.elt_pipeline.email}"

  depends_on = [google_project_service.iam]
}

# Storage Admin - read/write to GCS buckets
resource "google_storage_bucket_iam_member" "raw_zone_admin" {
  bucket = google_storage_bucket.raw_zone.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.elt_pipeline.email}"
}

resource "google_storage_bucket_iam_member" "processed_zone_admin" {
  bucket = google_storage_bucket.processed_zone.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.elt_pipeline.email}"
}

# Billing Account IAM - allow service account to create budgets
resource "google_billing_account_iam_member" "budget_admin" {
  count              = var.enable_billing_alert ? 1 : 0
  billing_account_id = data.google_billing_account.account.id
  role               = "roles/billing.admin"
  member             = "serviceAccount:${google_service_account.elt_pipeline.email}"
}

# ============================================================================
# 6. SERVICE ACCOUNT KEY (for local development & GitHub Actions)
# ============================================================================

resource "google_service_account_key" "elt_pipeline_key" {
  service_account_id = google_service_account.elt_pipeline.name
  public_key_type    = "TYPE_X509_PEM_FILE"

  # Key will be output to console - save securely!
}

# ============================================================================
# 7. BUDGET ALERT (Optional but recommended)
# ============================================================================

resource "google_billing_budget" "monthly_budget" {
  count           = var.enable_billing_alert ? 1 : 0
  billing_account = data.google_billing_account.account.id
  display_name    = "Monthly Budget Alert - Olist ELT Pipeline"

  budget_filter {
    projects = ["projects/${var.gcp_project_id}"]
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = var.monthly_budget_usd
    }
  }

  threshold_rules {
    threshold_percent = 50
  }

  threshold_rules {
    threshold_percent = 90
  }

  threshold_rules {
    threshold_percent = 100
  }

  depends_on = [google_project_service.billing_budgets]
}
