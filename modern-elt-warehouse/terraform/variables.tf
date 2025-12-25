# Terraform Variables
# ===================
# Define input variables for the GCP infrastructure configuration

variable "gcp_project_id" {
  description = "GCP Project ID (must already exist)"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.gcp_project_id))
    error_message = "Project ID must be 6-30 characters, start with lowercase letter, contain only lowercase letters, numbers, and hyphens."
  }
}

variable "gcp_region" {
  description = "GCP region for compute resources"
  type        = string
  default     = "us-central1"

  validation {
    condition     = can(regex("^[a-z]+-[a-z0-9]+$", var.gcp_region))
    error_message = "Region must be a valid GCP region."
  }
}

variable "bq_location" {
  description = "Location for BigQuery datasets (US, EU, asia-southeast1, etc.)"
  type        = string
  default     = "US"

  validation {
    condition     = contains(["US", "EU", "asia-southeast1", "asia-east1", "europe-west1"], var.bq_location)
    error_message = "Must be a valid BigQuery location."
  }
}

variable "enable_billing_alert" {
  description = "Enable budget alerts for cost monitoring"
  type        = bool
  default     = true
}

variable "monthly_budget_usd" {
  description = "Monthly budget in USD for billing alerts"
  type        = number
  default     = 1.0
  
  validation {
    condition     = var.monthly_budget_usd > 0
    error_message = "Budget must be greater than 0."
  }
}

variable "billing_account_id" {
  description = "GCP Billing Account ID (required if enable_billing_alert is true)"
  type        = string
  default     = ""
}

variable "environment" {
  description = "Environment name for labeling resources"
  type        = string
  default     = "production"

  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be development, staging, or production."
  }
}
