terraform {
  required_version = ">= 1.6"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
  
  backend "gcs" {
    bucket = "shipit-platform-terraform-state"
    prefix = "infrastructure"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "GCP region"
  default     = "us-central1"
}

variable "environment" {
  type        = string
  description = "Environment name (staging, production)"
  default     = "staging"
}

variable "domain" {
  type        = string
  description = "Custom domain for the control plane"
  default     = ""
}

locals {
  name_prefix = "shipit-${var.environment}"
  labels = {
    environment = var.environment
    managed-by  = "opentofu"
    platform    = "shipit"
  }
}

module "vpc" {
  source = "./modules/vpc"
  name_prefix = local.name_prefix
  labels      = local.labels
  region      = var.region
}

module "cloudsql" {
  source = "./modules/cloudsql"
  name_prefix = local.name_prefix
  labels      = local.labels
  region      = var.region
  vpc_network = module.vpc.network_name
  private_ip  = module.vpc.private_ip_range
}

module "secrets" {
  source = "./modules/secrets"
  name_prefix = local.name_prefix
  labels      = local.labels
  region      = var.region
}

module "artifacts" {
  source = "./modules/artifacts"
  name_prefix = local.name_prefix
  labels      = local.labels
  region      = var.region
}

module "cloudbuild" {
  source = "./modules/cloudbuild"
  name_prefix = local.name_prefix
  labels      = local.labels
  region      = var.region
  artifacts_repo = module.artifacts.repository_url
}

module "cloudrun" {
  source = "./modules/cloudrun"
  name_prefix = local.name_prefix
  labels      = local.labels
  region      = var.region
  vpc_connector = module.vpc.serverless_connector_name
  db_instance = module.cloudsql.instance_name
  db_password_secret = module.secrets.db_password_secret_name
  server_image = "ghcr.io/${var.project_id}/server:latest"
  client_image = "ghcr.io/${var.project_id}/client:latest"
  domain = var.domain
}

module "iam" {
  source = "./modules/iam"
  name_prefix = local.name_prefix
  labels      = local.labels
  project_id  = var.project_id
  cloudrun_sa = module.cloudrun.service_account_email
  cloudbuild_sa = module.cloudbuild.service_account_email
}

output "server_url" {
  value = module.cloudrun.server_url
  description = "Control plane server URL"
}

output "client_url" {
  value = module.cloudrun.client_url
  description = "Control plane client URL"
}

output "database_connection_name" {
  value = module.cloudsql.connection_name
  description = "Cloud SQL connection name"
}