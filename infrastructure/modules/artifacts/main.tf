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

resource "google_artifact_registry_repository" "docker" {
  location      = var.region
  repository_id = "${var.name_prefix}-docker"
  format        = "DOCKER"
  description   = "Docker images for ShipIt Platform"

  labels = var.labels
}

resource "google_artifact_registry_repository" "maven" {
  location      = var.region
  repository_id = "${var.name_prefix}-maven"
  format        = "MAVEN"
  description   = "Maven artifacts for ShipIt Platform"

  labels = var.labels
}

output "repository_url" {
  value = "${var.region}-docker.pkg.dev/${google_artifact_registry_repository.docker.project}/${google_artifact_registry_repository.docker.repository_id}"
}

output "maven_url" {
  value = "${var.region}-maven.pkg.dev/${google_artifact_registry_repository.maven.project}/${google_artifact_registry_repository.maven.repository_id}"
}