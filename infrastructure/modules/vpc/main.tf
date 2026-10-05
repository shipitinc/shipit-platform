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

resource "google_compute_network" "vpc" {
  name                    = "${var.name_prefix}-vpc"
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
  description             = "VPC for ShipIt Platform ${var.name_prefix}"

  labels = var.labels
}

resource "google_compute_subnetwork" "private" {
  name          = "${var.name_prefix}-private"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id
  purpose       = "PRIVATE"

  labels = var.labels
}

resource "google_compute_global_address" "private_ip" {
  name          = "${var.name_prefix}-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
  description   = "Private IP range for Cloud SQL VPC peering"

  labels = var.labels
}

resource "google_service_networking_connection" "private_ip" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip.name]
}

resource "google_compute_network_peering" "servicenetworking" {
  name         = "${var.name_prefix}-servicenetworking"
  network      = google_compute_network.vpc.id
  peer_network = "projects/servicenetworking/global/networks/servicenetworking"

  export_custom_routes = true
  import_custom_routes = true
}

resource "google_compute_subnetwork" "serverless" {
  name          = "${var.name_prefix}-serverless"
  ip_cidr_range = "10.0.1.0/28"
  region        = var.region
  network       = google_compute_network.vpc.id
  purpose       = "PRIVATE_SERVICE_CONNECT"

  labels = var.labels
}

resource "google_vpc_access_connector" "serverless" {
  name           = "${var.name_prefix}-connector"
  region         = var.region
  network        = google_compute_network.vpc.id
  subnet         = google_compute_subnetwork.serverless.id
  min_instances  = 2
  max_instances  = 10
  machine_type   = "e2-micro"

  labels = var.labels
}

output "network_name" {
  value = google_compute_network.vpc.name
}

output "private_ip_range" {
  value = google_compute_global_address.private_ip.name
}

output "serverless_connector_name" {
  value = google_vpc_access_connector.serverless.name
}