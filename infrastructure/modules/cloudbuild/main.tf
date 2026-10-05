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

variable "region" {
  type = string
}

variable "artifacts_repo" {
  type = string
}

resource "google_service_account" "cloudbuild" {
  account_id   = "${var.name_prefix}-cloudbuild"
  display_name = "ShipIt Cloud Build"
  labels       = var.labels
}

resource "google_cloudbuild_trigger" "main" {
  name        = "${var.name_prefix}-main"
  description = "Build and deploy on push to main"
  github {
    owner = "YOUR_ORG"
    name  = "shipit-platform"
    push {
      branch = "^main$"
    }
  }
  filename = "cloudbuild.yaml"
  service_account = google_service_account.cloudbuild.email
}

resource "google_cloudbuild_trigger" "release" {
  name        = "${var.name_prefix}-release"
  description = "Build and deploy on tag push"
  github {
    owner = "YOUR_ORG"
    name  = "shipit-platform"
    push {
      tag = "^v.*$"
    }
  }
  filename = "cloudbuild.release.yaml"
  service_account = google_service_account.cloudbuild.email
}

resource "google_project_iam_member" "cloudbuild_run_admin" {
  project = google_service_account.cloudbuild.project
  role    = "roles/run.admin"
  member  = "serviceAccount:${google_service_account.cloudbuild.email}"
}

resource "google_project_iam_member" "cloudbuild_artifact_writer" {
  project = google_service_account.cloudbuild.project
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.cloudbuild.email}"
}

resource "google_project_iam_member" "cloudbuild_secret_accessor" {
  project = google_service_account.cloudbuild.project
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.cloudbuild.email}"
}

resource "google_project_iam_member" "cloudbuild_sql_admin" {
  project = google_service_account.cloudbuild.project
  role    = "roles/cloudsql.admin"
  member  = "serviceAccount:${google_service_account.cloudbuild.email}"
}

resource "google_project_iam_member" "cloudbuild_storage_admin" {
  project = google_service_account.cloudbuild.project
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.cloudbuild.email}"
}

output "service_account_email" {
  value = google_service_account.cloudbuild.email
}