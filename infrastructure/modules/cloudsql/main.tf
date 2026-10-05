terraform {
  required_version = ">= 1.6"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
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

variable "vpc_network" {
  type = string
}

variable "private_ip" {
  type = string
}

resource "random_password" "db_password" {
  length  = 32
  special = false
  override_special = "_"
}

resource "google_sql_database_instance" "main" {
  name             = "${var.name_prefix}-db"
  region           = var.region
  database_version = "POSTGRES_16"
  deletion_protection = var.name_prefix != "shipit-staging"

  settings {
    tier              = "db-f1-micro"
    availability_type = "ZONAL"
    backup_configuration {
      enabled                        = true
      start_time                     = "03:00"
      point_in_time_recovery_enabled = true
    }
    ip_configuration {
      private_network = var.vpc_network
      allocated_ip_range_name = var.private_ip
      require_ssl = true
    }
    database_flags {
      name  = "cloudsql.iam_authentication"
      value = "on"
    }
    insights_config {
      query_insights_enabled = true
    }
  }

  labels = var.labels
}

resource "google_sql_database" "shipit" {
  name     = "shipit"
  instance = google_sql_database_instance.main.name
}

resource "google_secret_manager_secret" "db_password" {
  secret_id = "${var.name_prefix}-db-password"
  replication {
    automatic = true
  }
  labels = var.labels
}

resource "google_secret_manager_secret_version" "db_password" {
  secret = google_secret_manager_secret.db_password.id
  secret_data = random_password.db_password.result
}

output "instance_name" {
  value = google_sql_database_instance.main.name
}

output "connection_name" {
  value = google_sql_database_instance.main.connection_name
}

output "db_password_secret_name" {
  value = google_secret_manager_secret.db_password.secret_id
}