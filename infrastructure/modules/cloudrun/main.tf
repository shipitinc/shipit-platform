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

variable "vpc_connector" {
  type = string
}

variable "db_instance" {
  type = string
}

variable "db_password_secret" {
  type = string
}

variable "server_image" {
  type = string
}

variable "client_image" {
  type = string
}

variable "domain" {
  type = string
  default = ""
}

resource "google_service_account" "server" {
  account_id   = "${var.name_prefix}-server"
  display_name = "ShipIt Platform Server"
  labels       = var.labels
}

resource "google_service_account" "client" {
  account_id   = "${var.name_prefix}-client"
  display_name = "ShipIt Platform Client"
  labels       = var.labels
}

resource "google_cloud_run_v2_service" "server" {
  name     = "${var.name_prefix}-server"
  location = var.region
  template {
    service_account = google_service_account.server.email
    containers {
      image = var.server_image
      ports {
        container_port = 8080
      }
      env {
        name  = "SERVERPOD_DATABASE_HOST"
        value = "/cloudsql/${var.db_instance}"
      }
      env {
        name  = "SERVERPOD_DATABASE_NAME"
        value = "shipit"
      }
      env {
        name  = "SERVERPOD_DATABASE_USER"
        value = "shipit"
      }
      env {
        name        = "SERVERPOD_DATABASE_PASSWORD"
        value       = var.db_password_secret
        value_source = "secret_key_ref"
      }
      resources {
        limits = {
          cpu    = "1000m"
          memory = "1Gi"
        }
      }
      startup_probe {
        initial_delay_seconds = 5
        period_seconds        = 10
        timeout_seconds       = 5
        failure_threshold     = 30
        http_get {
          path = "/health"
          port = 8080
        }
      }
      liveness_probe {
        initial_delay_seconds = 30
        period_seconds        = 10
        timeout_seconds       = 5
        failure_threshold     = 3
        http_get {
          path = "/health"
          port = 8080
        }
      }
    }
    vpc_access {
      egress           = "PRIVATE_RANGES_ONLY"
      network_interfaces {
        network = var.vpc_connector
      }
    }
    scaling {
      min_instance_count = 1
      max_instance_count = 10
    }
    labels = var.labels
  }
  traffics {
    percent         = 100
    latest_revision = true
  }
}

resource "google_cloud_run_v2_service" "client" {
  name     = "${var.name_prefix}-client"
  location = var.region
  template {
    service_account = google_service_account.client.email
    containers {
      image = var.client_image
      ports {
        container_port = 8081
      }
      env {
        name  = "SERVERPOD_API_URL"
        value = "https://${google_cloud_run_v2_service.server.uri}/"
      }
      resources {
        limits = {
          cpu    = "500m"
          memory = "512Mi"
        }
      }
    }
    scaling {
      min_instance_count = 1
      max_instance_count = 5
    }
    labels = var.labels
  }
  traffics {
    percent         = 100
    latest_revision = true
  }
}

resource "google_cloud_run_v2_service_iam_member" "server_public" {
  service  = google_cloud_run_v2_service.server.name
  location = var.region
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_v2_service_iam_member" "client_public" {
  service  = google_cloud_run_v2_service.client.name
  location = var.region
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_v2_domain_mapping" "server" {
  count = var.domain != "" ? 1 : 0
  name     = "api.${var.domain}"
  location = var.region
  metadata {
    namespace = "shipit"
  }
  spec {
    route_name = google_cloud_run_v2_service.server.name
  }
}

resource "google_cloud_run_v2_domain_mapping" "client" {
  count = var.domain != "" ? 1 : 0
  name     = "${var.domain}"
  location = var.region
  metadata {
    namespace = "shipit"
  }
  spec {
    route_name = google_cloud_run_v2_service.client.name
  }
}

output "server_url" {
  value = google_cloud_run_v2_service.server.uri
}

output "client_url" {
  value = google_cloud_run_v2_service.client.uri
}

output "service_account_email" {
  value = google_service_account.server.email
}