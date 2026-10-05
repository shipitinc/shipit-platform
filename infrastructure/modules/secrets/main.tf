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

resource "google_secret_manager_secret" "github_token" {
  secret_id = "${var.name_prefix}-github-token"
  replication {
    automatic = true
  }
  labels = var.labels
}

resource "google_secret_manager_secret" "penpot_token" {
  secret_id = "${var.name_prefix}-penpot-token"
  replication {
    automatic = true
  }
  labels = var.labels
}

resource "google_secret_manager_secret" "serverpod_signing_key" {
  secret_id = "${var.name_prefix}-serverpod-signing-key"
  replication {
    automatic = true
  }
  labels = var.labels
}

output "db_password_secret_name" {
  value = "${var.name_prefix}-db-password"
}

output "github_token_secret_name" {
  value = google_secret_manager_secret.github_token.secret_id
}

output "penpot_token_secret_name" {
  value = google_secret_manager_secret.penpot_token.secret_id
}

output "serverpod_signing_key_secret_name" {
  value = google_secret_manager_secret.serverpod_signing_key.secret_id
}