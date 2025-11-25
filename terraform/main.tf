terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  # Backend configuration for storing state in GCS
  # Uncomment and configure after creating a GCS bucket
  # backend "gcs" {
  #   bucket = "your-terraform-state-bucket"
  #   prefix = "project-02/terraform.tfstate"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}
