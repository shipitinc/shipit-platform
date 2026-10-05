terraform {
  required_version = ">= 1.6"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

variable "name_prefix" {
  type = string
}

variable "labels" {
  type = map(string)
}

variable "project_id" {
  type = string
}

variable "cloudrun_sa" {
  type = string
}

variable "cloudbuild_sa" {
  type = string
}

resource "google_project_iam_member" "cloudrun_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${var.cloudrun_sa}"
}

resource "google_project_iam_member" "cloudrun_sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${var.cloudrun_sa}"
}

resource "google_project_iam_member" "cloudrun_logging_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${var.cloudrun_sa}"
}

resource "google_project_iam_member" "cloudrun_monitoring_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${var.cloudrun_sa}"
}

resource "google_project_iam_member" "cloudrun_trace_agent" {
  project = var.project_id
  role    = "roles/cloudtrace.agent"
  member  = "serviceAccount:${var.cloudrun_sa}"
}

resource "google_project_iam_member" "cloudbuild_run_deployer" {
  project = var.project_id
  role    = "roles/run.developer"
  member  = "serviceAccount:${var.cloudbuild_sa}"
}